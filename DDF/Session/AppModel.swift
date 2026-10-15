import Foundation
import Observation

/// Lobby-Zustand: Spielerliste, Einstellungen (beides gespeichert) und das laufende Spiel.
@MainActor
@Observable
final class AppModel {
    var players: [Player] { didSet { save() } }
    var settings: GameSettings { didSet { save() } }
    /// Wer beim letzten Spiel dabei war, für „Gleiche Runde wie letztes Mal“.
    private(set) var lastGroup: [Player] { didSet { save() } }
    private(set) var session: GameSession?
    /// Fragen, die schon einmal dran waren. Neue Fragen haben Vorrang, auch über mehrere Abende.
    private(set) var seenQuestionIDs: Set<String> { didSet { saveSeen() } }
    /// Beim Spielen gemeldete Fragen, zum späteren Prüfen.
    private(set) var reports: [QuestionReport] { didSet { saveReports() } }

    let questions: [Question]
    static let maxPlayers = 12
    static let paletteCount = 8

    private let defaults: UserDefaults
    private enum Key {
        static let players = "ddf.players"
        static let settings = "ddf.settings"
        static let lastGroup = "ddf.lastGroup"
        static let seen = "ddf.seenQuestions"
        static let reports = "ddf.reports"
    }

    init(defaults: UserDefaults = .standard, questions: [Question] = QuestionBank.loadAll()) {
        self.defaults = defaults
        self.questions = questions
        let decoder = JSONDecoder()
        let saved = defaults.data(forKey: Key.players).flatMap { try? decoder.decode([Player].self, from: $0) } ?? []
        // Frühere Versionen haben vier Beispielspieler gespeichert. Die sollen nicht stehen bleiben.
        players = saved.map(\.name) == Self.oldExamplePlayers ? [] : saved
        lastGroup = defaults.data(forKey: Key.lastGroup).flatMap { try? decoder.decode([Player].self, from: $0) } ?? []
        settings = defaults.data(forKey: Key.settings).flatMap { try? decoder.decode(GameSettings.self, from: $0) }
            ?? GameSettings()
        seenQuestionIDs = Set(defaults.stringArray(forKey: Key.seen) ?? [])
        reports = defaults.data(forKey: Key.reports).flatMap { try? decoder.decode([QuestionReport].self, from: $0) } ?? []
    }

    private static let oldExamplePlayers = ["Lena", "Murat", "Jonas", "Aylin"]

    var canStart: Bool { players.count >= 2 && !questionPool.isEmpty }

    /// Fragen für das nächste Spiel: nur eingeschaltete Kategorien.
    /// Bei Multiple Choice zählen nur Fragen mit genug falschen Antworten.
    var questionPool: [Question] {
        questions.filter { q in
            !settings.excludedCategories.contains(q.category)
                && (settings.answerMode == .host || q.supportsMultipleChoice)
        }
    }

    /// Alle Kategorien mit Anzahl der Fragen, alphabetisch. „Allgemein“ steht vorne.
    var categories: [(name: String, count: Int)] {
        Dictionary(grouping: questions, by: \.category)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { a, b in
                if (a.name == "Allgemein") != (b.name == "Allgemein") { return a.name == "Allgemein" }
                return a.name.localizedCompare(b.name) == .orderedAscending
            }
    }

    func setCategory(_ name: String, enabled: Bool) {
        if enabled {
            settings.excludedCategories.remove(name)
        } else {
            settings.excludedCategories.insert(name)
        }
    }

    func setAllCategories(enabled: Bool) {
        settings.excludedCategories = enabled ? [] : Set(questions.map(\.category))
    }

    func report(_ question: Question, reason: QuestionReport.Reason) {
        let entry = QuestionReport(questionID: question.id, category: question.category, text: question.text,
                                   answer: question.answer, reason: reason, date: Date())
        reports.removeAll { $0.id == entry.id }
        reports.append(entry)
    }

    func clearReports() {
        reports = []
    }

    /// Die Meldungen als Text zum Teilen, zum Beispiel per Nachricht oder Mail.
    var reportsText: String {
        let lines = reports.sorted { $0.date < $1.date }.map {
            "[\($0.reason.label)] \($0.questionID) (\($0.category)): \($0.text) → \($0.answer)"
        }
        return "Gemeldete Fragen (\(reports.count))\n\n" + lines.joined(separator: "\n")
    }

    /// Warum nicht gestartet werden kann, als Hinweis für den Startscreen.
    var startHint: String? {
        if players.count < 2 { return "Fügt mindestens 2 Spieler mit + hinzu." }
        if questionPool.isEmpty { return "Keine Kategorie ausgewählt. Schalte in den Regeln mindestens eine ein." }
        return nil
    }

    func addPlayer(named rawName: String, colorIndex: Int? = nil, handicap: Int = 0) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, players.count < Self.maxPlayers else { return }
        let used = Set(players.map(\.colorIndex))
        let color = colorIndex ?? (0..<Self.paletteCount).first { !used.contains($0) } ?? players.count % Self.paletteCount
        players.append(Player(name: String(name.prefix(14)), colorIndex: color, handicap: handicap))
    }

    func updatePlayer(_ id: UUID, name rawName: String, colorIndex: Int, handicap: Int) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let i = players.firstIndex(where: { $0.id == id }) else { return }
        players[i].name = String(name.prefix(14))
        players[i].colorIndex = colorIndex
        players[i].handicap = min(max(handicap, -1), 1)
    }

    func removePlayer(_ id: UUID) {
        players.removeAll { $0.id == id }
    }

    /// Die letzte Gruppe lässt sich zurückholen, wenn die aktuelle Liste anders aussieht.
    var canRestoreLastGroup: Bool {
        !lastGroup.isEmpty && Set(lastGroup.map(\.id)) != Set(players.map(\.id))
    }

    func restoreLastGroup() {
        players = lastGroup
    }

    func removeAllPlayers() {
        players = []
    }

    func startGame() {
        guard canStart else { return }
        lastGroup = players
        let pool = questionPool
        // Alles schon gesehen? Dann beginnt der Durchlauf für diese Fragen von vorn.
        if pool.allSatisfy({ seenQuestionIDs.contains($0.id) }) {
            seenQuestionIDs.subtract(pool.map(\.id))
        }
        let session = GameSession(players: players.shuffled(), settings: settings, questions: pool, seen: seenQuestionIDs)
        session.onQuestionShown = { [weak self] question in self?.seenQuestionIDs.insert(question.id) }
        session.onReport = { [weak self] question, reason in self?.report(question, reason: reason) }
        self.session = session
    }

    func restartWithSamePlayers() {
        session?.end()
        session = nil
        startGame()
    }

    func endGame() {
        session?.end()
        session = nil
    }

    private func saveSeen() {
        defaults.set(Array(seenQuestionIDs), forKey: Key.seen)
    }

    private func saveReports() {
        if let data = try? JSONEncoder().encode(reports) { defaults.set(data, forKey: Key.reports) }
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(players) { defaults.set(data, forKey: Key.players) }
        if let data = try? encoder.encode(settings) { defaults.set(data, forKey: Key.settings) }
        if let data = try? encoder.encode(lastGroup) { defaults.set(data, forKey: Key.lastGroup) }
    }
}
