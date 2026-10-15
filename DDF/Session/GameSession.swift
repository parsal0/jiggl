import Foundation
import Observation

/// Verbindet die Spiel-Logik mit der Zeit: Antwort-Timer, Rundenzeit im Abstimmungs-Modus und Pause.
@MainActor
@Observable
final class GameSession {
    private(set) var engine: GameEngine
    /// Bis wann die aktuelle Frage beantwortet werden muss.
    private(set) var turnDeadline: Date?
    /// Bis wann die aktuelle Abstimmungs-Runde läuft.
    private(set) var roundDeadline: Date?
    private(set) var isPaused = false

    private var pausedTurnRemaining: TimeInterval?
    private var pausedRoundRemaining: TimeInterval?
    private var turnTask: Task<Void, Never>?
    private var roundTask: Task<Void, Never>?
    private var roundTimerFor = 0

    /// Meldet jede gezeigte Frage, damit sie an späteren Abenden erst nach neuen Fragen wiederkommt.
    var onQuestionShown: ((Question) -> Void)?
    /// Speichert eine gemeldete Frage.
    var onReport: ((Question, QuestionReport.Reason) -> Void)?

    init(players: [Player], settings: GameSettings, questions: [Question], seen: Set<String> = []) {
        engine = GameEngine(players: players, settings: settings, questions: questions, seen: seen)
    }

    func report(_ question: Question, reason: QuestionReport.Reason) {
        onReport?(question, reason)
    }

    var settings: GameSettings { engine.settings }
    var phase: Phase { engine.phase }

    func player(_ id: UUID) -> PlayerState? { engine.player(id) }

    func turnRemaining(at date: Date) -> TimeInterval {
        if let paused = pausedTurnRemaining { return paused }
        guard let deadline = turnDeadline else { return TimeInterval(max(settings.answerTime, 0)) }
        return max(0, deadline.timeIntervalSince(date))
    }

    func roundRemaining(at date: Date) -> TimeInterval? {
        if let paused = pausedRoundRemaining { return paused }
        guard let deadline = roundDeadline else { return nil }
        return max(0, deadline.timeIntervalSince(date))
    }

    // MARK: - Aktionen

    func startTurn() {
        // Die Rundenuhr startet mit der ersten Frage einer Abstimmungs-Runde.
        if settings.hasRoundTimer, engine.isVoteRoundRunning, roundTimerFor != engine.round, engine.phase == .turnIntro {
            roundTimerFor = engine.round
            scheduleRoundTimeout(after: TimeInterval(settings.roundDuration))
        }
        engine.startTurn()
        guard case .asking(let turn) = engine.phase else { return }
        onQuestionShown?(turn.question)
        guard settings.hasAnswerTimer else { return }
        scheduleTurnTimeout(after: TimeInterval(settings.answerTime))
    }

    func answer(_ outcome: AnswerOutcome) {
        cancelTurnTimer()
        engine.answer(outcome)
    }

    func choose(option index: Int) {
        cancelTurnTimer()
        engine.choose(option: index)
    }

    var canUndoAnswer: Bool { engine.canUndoAnswer }

    /// Nimmt eine Fehleingabe des Spielleiters zurück. Die Antwortzeit beginnt von vorn.
    func undoAnswer() {
        engine.undoAnswer()
        guard case .asking = engine.phase, settings.hasAnswerTimer else { return }
        if isPaused {
            pausedTurnRemaining = TimeInterval(settings.answerTime)
        } else {
            scheduleTurnTimeout(after: TimeInterval(settings.answerTime))
        }
    }

    func continueAfterFeedback() {
        engine.continueAfterFeedback()
        syncRoundTimer()
        // In einer Abstimmungs-Runde geht es ohne „X ist dran“ direkt mit der nächsten Frage weiter.
        // Nur die erste Frage einer Runde bekommt die Ansage.
        if engine.isVoteRoundRunning, engine.phase == .turnIntro {
            startTurn()
        }
    }

    func beginVoting() { engine.beginVoting() }

    func castVote(for id: UUID) { engine.castVote(for: id) }

    func continueAfterVoteResult() {
        engine.continueAfterVoteResult()
        syncRoundTimer()
    }

    func continueAfterElimination() {
        engine.continueAfterElimination()
        syncRoundTimer()
    }

    func startFinale() {
        engine.startFinale()
        syncRoundTimer()
    }

    func pause() {
        guard !isPaused else { return }
        let now = Date()
        isPaused = true
        if let deadline = turnDeadline { pausedTurnRemaining = max(0, deadline.timeIntervalSince(now)) }
        if let deadline = roundDeadline { pausedRoundRemaining = max(0, deadline.timeIntervalSince(now)) }
        turnTask?.cancel()
        roundTask?.cancel()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        if let remaining = pausedTurnRemaining { scheduleTurnTimeout(after: remaining) }
        if let remaining = pausedRoundRemaining { scheduleRoundTimeout(after: remaining) }
        pausedTurnRemaining = nil
        pausedRoundRemaining = nil
    }

    var isOver: Bool {
        if case .winner = engine.phase { return true }
        return false
    }

    /// Die App geht in den Hintergrund (Anruf, Sperrbildschirm, Kontrollzentrum): alle Uhren anhalten.
    /// Gibt zurück, ob dadurch pausiert wurde, damit das Pausenmenü erscheinen kann.
    @discardableResult
    func pauseForBackground() -> Bool {
        guard !isPaused, !isOver else { return false }
        pause()
        return true
    }

    /// Ob die laufende Abstimmungs-Runde von Hand beendet werden kann (Runde ohne Zeitlimit).
    var canEndRoundManually: Bool {
        !settings.hasRoundTimer && engine.isVoteRoundRunning && !engine.roundTimeUp
    }

    /// Beendet eine Runde ohne Zeitlimit: Nach der aktuellen Frage wird abgestimmt.
    func endRoundManually() {
        guard canEndRoundManually else { return }
        engine.markRoundTimeUp()
    }

    #if DEBUG
    /// Nur für Demo-Starts: beendet die laufende Abstimmungs-Runde sofort.
    func debugEndRound() {
        roundTask?.cancel()
        roundDeadline = nil
        engine.markRoundTimeUp()
    }
    #endif

    func end() {
        turnTask?.cancel()
        roundTask?.cancel()
    }

    // MARK: - Timer

    private func scheduleTurnTimeout(after seconds: TimeInterval) {
        turnTask?.cancel()
        turnDeadline = Date().addingTimeInterval(seconds)
        turnTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, !self.isPaused else { return }
            self.turnDeadline = nil
            self.engine.answer(.timeout)
        }
    }

    private func cancelTurnTimer() {
        turnTask?.cancel()
        turnTask = nil
        turnDeadline = nil
        pausedTurnRemaining = nil
    }

    /// Im Finale gibt es keine Rundenuhr mehr.
    private func syncRoundTimer() {
        guard !engine.isVoteRoundRunning else { return }
        roundTask?.cancel()
        roundDeadline = nil
        pausedRoundRemaining = nil
    }

    private func scheduleRoundTimeout(after seconds: TimeInterval) {
        roundTask?.cancel()
        roundDeadline = Date().addingTimeInterval(seconds)
        roundTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, !self.isPaused else { return }
            self.roundDeadline = nil
            self.engine.markRoundTimeUp()
        }
    }
}
