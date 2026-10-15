import Foundation

struct Player: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorIndex: Int
    /// Handicap: −1 = leichtere Fragen, 0 = normal, +1 = schwerere Fragen.
    var handicap: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int, handicap: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.handicap = min(max(handicap, -1), 1)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decode(Int.self, forKey: .colorIndex)
        handicap = try c.decodeIfPresent(Int.self, forKey: .handicap) ?? 0
    }

    var initial: String { String(name.prefix(1)).uppercased() }
}

struct Question: Identifiable, Hashable, Codable {
    let id: String
    let category: String
    /// 1 = leicht, 2 = mittel, 3 = schwer
    let difficulty: Int
    let text: String
    let answer: String
    /// Falsche Antworten für Multiple Choice. Fragen ohne genug falsche Antworten gibt es nur im Spielleiter-Modus.
    let wrongAnswers: [String]

    var supportsMultipleChoice: Bool { wrongAnswers.count >= 3 || isTrueFalse }

    /// Wahr-oder-falsch-Aussage: Antwort ist „Wahr“ oder „Falsch“, das Gegenteil steht in `w`.
    var isTrueFalse: Bool {
        wrongAnswers.count == 1 && Set([answer] + wrongAnswers) == [Self.trueAnswer, Self.falseAnswer]
    }

    static let trueAnswer = "Wahr"
    static let falseAnswer = "Falsch"

    enum CodingKeys: String, CodingKey {
        case id, category = "c", difficulty = "d", text = "q", answer = "a", wrongAnswers = "w"
    }

    init(id: String, category: String, difficulty: Int, text: String, answer: String, wrongAnswers: [String]) {
        self.id = id
        self.category = category
        self.difficulty = difficulty
        self.text = text
        self.answer = answer
        self.wrongAnswers = wrongAnswers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        category = try c.decode(String.self, forKey: .category)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 2
        text = try c.decode(String.self, forKey: .text)
        answer = try c.decode(String.self, forKey: .answer)
        wrongAnswers = try c.decodeIfPresent([String].self, forKey: .wrongAnswers) ?? []
    }
}

enum AnswerMode: String, Codable, CaseIterable, Hashable {
    /// Ein Spielleiter liest vor und entscheidet „richtig“ oder „falsch“.
    case host
    /// Vier Antworten zur Auswahl, die App prüft.
    case multipleChoice
}

enum EliminationMode: String, Codable, CaseIterable, Hashable {
    /// Jede falsche Antwort kostet ein Leben.
    case lives
    /// Eine Runde läuft auf Zeit, danach stimmen alle ab. Wer die meisten Stimmen hat, verliert ein Leben.
    case vote
}

struct GameSettings: Codable, Hashable {
    var lives: Int = 3
    /// Sekunden pro Antwort. 0 = ohne Zeitlimit.
    var answerTime: Int = 15
    var eliminationMode: EliminationMode = .lives
    /// Rundenlänge in Sekunden (nur im Abstimmungs-Modus). 0 = ohne Zeitlimit, die Runde wird von Hand beendet.
    var roundDuration: Int = 180
    var answerMode: AnswerMode = .host
    /// Leben pro Spieler im Finale (Duell der letzten zwei).
    var finaleLives: Int = 3
    /// Abgewählte Kategorien. Gespeichert wird, was aus ist, damit neue Kategorien automatisch an sind.
    var excludedCategories: Set<String> = []

    init() {}

    /// Fehlende Felder (aus älteren App-Versionen) bekommen ihren Standardwert.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GameSettings()
        lives = try c.decodeIfPresent(Int.self, forKey: .lives) ?? d.lives
        answerTime = try c.decodeIfPresent(Int.self, forKey: .answerTime) ?? d.answerTime
        eliminationMode = try c.decodeIfPresent(EliminationMode.self, forKey: .eliminationMode) ?? d.eliminationMode
        roundDuration = try c.decodeIfPresent(Int.self, forKey: .roundDuration) ?? d.roundDuration
        answerMode = try c.decodeIfPresent(AnswerMode.self, forKey: .answerMode) ?? d.answerMode
        finaleLives = try c.decodeIfPresent(Int.self, forKey: .finaleLives) ?? d.finaleLives
        excludedCategories = try c.decodeIfPresent(Set<String>.self, forKey: .excludedCategories) ?? d.excludedCategories
    }

    static let livesRange = 1...5
    static let answerTimeOptions = [5, 10, 15, 20, 30]
    static let roundDurationOptions = [60, 120, 180, 300]

    /// Grenzen für eigene Werte.
    static let customLivesRange = 1...99
    static let customAnswerTimeRange = 3...600
    static let customRoundMinutesRange = 1...120

    var hasAnswerTimer: Bool { answerTime > 0 }
    var hasRoundTimer: Bool { roundDuration > 0 }
}

struct PlayerState: Identifiable, Hashable {
    let player: Player
    var lives: Int
    var isOut = false
    var roundCorrect = 0
    var roundWrong = 0
    var totalCorrect = 0
    var totalWrong = 0
    /// 1 = zuerst rausgeflogen.
    var eliminationRank: Int?

    var id: UUID { player.id }
}

enum AnswerOutcome: Hashable {
    case correct
    case wrong
    case timeout

    var isCorrect: Bool { self == .correct }
}

struct Turn: Hashable {
    let playerID: UUID
    let question: Question
    /// Antwortoptionen in Anzeige-Reihenfolge (nur Multiple Choice).
    let options: [String]
    let number: Int

    var correctOptionIndex: Int? { options.firstIndex(of: question.answer) }
}

struct TurnResult: Hashable {
    let turn: Turn
    let outcome: AnswerOutcome
    let chosenOption: Int?
    let lostLife: Bool
    let livesLeft: Int
}

struct VoteResult: Hashable {
    let playerID: UUID
    /// Stimmen pro Spieler.
    let tally: [UUID: Int]
    /// true, wenn ein Gleichstand per Rundenstatistik oder Zufall entschieden wurde.
    let wasTieBreak: Bool
}

enum Phase: Hashable {
    case turnIntro
    case asking(Turn)
    case feedback(TurnResult)
    case roundOver
    case voting(voterIndex: Int)
    case voteResult(VoteResult)
    case elimination(UUID)
    case finaleIntro
    case winner(UUID)
}

/// Eine Frage, die beim Spielen als fehlerhaft gemeldet wurde.
struct QuestionReport: Codable, Hashable, Identifiable {
    enum Reason: String, Codable, CaseIterable {
        case wrong
        case unclear

        var label: String {
            switch self {
            case .wrong: "Stimmt nicht"
            case .unclear: "Unklar"
            }
        }
    }

    var id: String { questionID + reason.rawValue }
    let questionID: String
    let category: String
    let text: String
    let answer: String
    let reason: Reason
    let date: Date
}
