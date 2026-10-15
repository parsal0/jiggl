import Foundation

/// Die komplette Spiel-Logik als reiner Zustandsautomat. Kennt weder Uhrzeit noch Oberfläche:
/// Timer und Animationen steuert `GameSession`, hier wird nur entschieden, was als Nächstes passiert.
struct GameEngine {
    let settings: GameSettings
    private(set) var players: [PlayerState]
    private(set) var phase: Phase { didSet { step += 1 } }
    /// Zählt jeden Phasenwechsel. Damit liegt beim Übergang immer der neuere Screen oben.
    private(set) var step = 0
    private(set) var currentIndex = 0
    private(set) var questionNumber = 0
    private(set) var round = 1
    private(set) var isFinale = false
    private(set) var roundTimeUp = false
    private(set) var votes: [UUID: UUID] = [:]
    /// Alle beantworteten Fragen in Reihenfolge, z. B. für „Dümmste Antwort des Abends“.
    private(set) var history: [TurnResult] = []

    /// Stand vor der letzten Antwort, damit der Spielleiter einen Fehlklick zurücknehmen kann.
    private var beforeAnswer: (players: [PlayerState], turn: Turn)?

    private var deck: QuestionDeck
    private var rng: SplitMix64
    private let startingCount: Int
    private var eliminatedCount = 0

    init(players: [Player], settings: GameSettings, questions: [Question], seen: Set<String> = [],
         seed: UInt64 = .random(in: .min ... .max)) {
        precondition(players.count >= 2, "Mindestens zwei Spieler")
        var rng = SplitMix64(seed: seed)
        self.settings = settings
        self.players = players.map { PlayerState(player: $0, lives: settings.lives) }
        self.deck = QuestionDeck(questions: questions, answerMode: settings.answerMode, seen: seen, rng: &rng)
        self.rng = rng
        self.startingCount = players.count
        // Zu zweit ist das ganze Spiel direkt das Finale.
        self.phase = players.count == 2 ? .finaleIntro : .turnIntro
    }

    // MARK: - Abfragen

    var activePlayers: [PlayerState] { players.filter { !$0.isOut } }
    var currentPlayer: PlayerState { players[currentIndex] }
    var hasQuestions: Bool { !deck.isEmpty }

    /// true, wenn falsche Antworten Leben kosten (Leben-Modus und immer im Finale).
    var wrongAnswersCostLives: Bool { settings.eliminationMode == .lives || isFinale }
    var isVoteRoundRunning: Bool { settings.eliminationMode == .vote && !isFinale }

    /// Die letzte Antwort lässt sich zurücknehmen, solange die Auflösung zu sehen ist.
    var canUndoAnswer: Bool {
        if case .feedback = phase { return beforeAnswer != nil }
        return false
    }

    /// 0 = Spielbeginn, 1 = Finale. Steuert die Schwierigkeit.
    var progress: Double {
        if isFinale { return 1 }
        return Double(eliminatedCount) / Double(max(startingCount - 2, 1))
    }

    func player(_ id: UUID) -> PlayerState? { players.first { $0.id == id } }

    /// Wer abstimmt, in fester Reihenfolge.
    var voters: [PlayerState] { activePlayers }

    func candidates(forVoterAt index: Int) -> [PlayerState] {
        guard voters.indices.contains(index) else { return [] }
        let voterID = voters[index].id
        return activePlayers.filter { $0.id != voterID }
    }

    /// Platzierung: Sieger zuerst, dann in umgekehrter Reihenfolge des Rausfliegens.
    var ranking: [PlayerState] {
        players.sorted { a, b in
            switch (a.eliminationRank, b.eliminationRank) {
            case (nil, nil): return a.lives > b.lives
            case (nil, _): return true
            case (_, nil): return false
            case let (ra?, rb?): return ra > rb
            }
        }
    }

    // MARK: - Aktionen

    mutating func startTurn() {
        guard phase == .turnIntro, let question = deck.draw(progress: progress, handicap: currentPlayer.player.handicap, rng: &rng) else { return }
        questionNumber += 1
        var options: [String] = []
        if question.isTrueFalse {
            // Auch im Spielleiter-Modus: Gedrückt wird die Antwort des Spielers, nicht die Bewertung.
            // Sonst verwechselt man „Falsch“ als Antwort mit „Falsch“ als Urteil.
            // Immer gleiche Reihenfolge, damit „Wahr“ links und „Falsch“ rechts steht.
            options = [Question.trueAnswer, Question.falseAnswer]
        } else if settings.answerMode == .multipleChoice {
            let wrong = question.wrongAnswers.shuffled(using: &rng).prefix(3)
            options = ([question.answer] + wrong).shuffled(using: &rng)
        }
        phase = .asking(Turn(playerID: currentPlayer.id, question: question, options: options, number: questionNumber))
    }

    mutating func answer(_ outcome: AnswerOutcome, chosenOption: Int? = nil) {
        guard case .asking(let turn) = phase else { return }
        beforeAnswer = (players, turn)
        let i = currentIndex
        var lostLife = false
        if outcome.isCorrect {
            players[i].roundCorrect += 1
            players[i].totalCorrect += 1
        } else {
            players[i].roundWrong += 1
            players[i].totalWrong += 1
            if wrongAnswersCostLives {
                players[i].lives -= 1
                lostLife = true
            }
        }
        let result = TurnResult(turn: turn, outcome: outcome, chosenOption: chosenOption,
                                lostLife: lostLife, livesLeft: players[i].lives)
        history.append(result)
        phase = .feedback(result)
    }

    /// Nimmt die letzte Antwort zurück: Leben und Zähler wie vorher, die Frage ist wieder offen.
    mutating func undoAnswer() {
        guard canUndoAnswer, let saved = beforeAnswer else { return }
        players = saved.players
        history.removeLast()
        beforeAnswer = nil
        phase = .asking(saved.turn)
    }

    mutating func choose(option index: Int) {
        guard case .asking(let turn) = phase, turn.options.indices.contains(index) else { return }
        answer(turn.options[index] == turn.question.answer ? .correct : .wrong, chosenOption: index)
    }

    /// Die Rundenzeit im Abstimmungs-Modus ist abgelaufen. Eine laufende Frage wird noch zu Ende gespielt.
    mutating func markRoundTimeUp() {
        guard isVoteRoundRunning, !roundTimeUp else { return }
        roundTimeUp = true
        if phase == .turnIntro { phase = .roundOver }
    }

    mutating func continueAfterFeedback() {
        guard case .feedback = phase else { return }
        beforeAnswer = nil
        if players[currentIndex].lives <= 0 {
            eliminate(currentIndex)
        } else if roundTimeUp {
            phase = .roundOver
        } else {
            advanceToNextPlayer()
            phase = .turnIntro
        }
    }

    mutating func beginVoting() {
        guard phase == .roundOver else { return }
        votes = [:]
        phase = .voting(voterIndex: 0)
    }

    mutating func castVote(for candidate: UUID) {
        guard case .voting(let index) = phase, voters.indices.contains(index) else { return }
        let voter = voters[index]
        guard candidate != voter.id, activePlayers.contains(where: { $0.id == candidate }) else { return }
        votes[voter.id] = candidate
        if index + 1 < voters.count {
            phase = .voting(voterIndex: index + 1)
        } else {
            phase = .voteResult(tallyVotes())
        }
    }

    mutating func continueAfterVoteResult() {
        guard case .voteResult(let result) = phase,
              let i = players.firstIndex(where: { $0.id == result.playerID }) else { return }
        players[i].lives -= 1
        if players[i].lives <= 0 {
            eliminate(i)
        } else {
            startNextRound()
        }
    }

    mutating func continueAfterElimination() {
        guard case .elimination(let id) = phase else { return }
        let active = activePlayers
        if active.count <= 1 {
            phase = .winner(active.first?.id ?? id)
        } else if active.count == 2 && !isFinale {
            phase = .finaleIntro
        } else if isVoteRoundRunning {
            startNextRound()
        } else {
            advanceToNextPlayer()
            phase = .turnIntro
        }
    }

    mutating func startFinale() {
        guard phase == .finaleIntro else { return }
        isFinale = true
        roundTimeUp = false
        for i in players.indices where !players[i].isOut {
            players[i].lives = settings.finaleLives
            players[i].roundCorrect = 0
            players[i].roundWrong = 0
        }
        advanceToNextPlayer()
        phase = .turnIntro
    }

    // MARK: - Intern

    private mutating func eliminate(_ i: Int) {
        players[i].isOut = true
        players[i].lives = 0
        eliminatedCount += 1
        players[i].eliminationRank = eliminatedCount
        phase = .elimination(players[i].id)
    }

    private mutating func startNextRound() {
        round += 1
        roundTimeUp = false
        votes = [:]
        for i in players.indices {
            players[i].roundCorrect = 0
            players[i].roundWrong = 0
        }
        advanceToNextPlayer()
        phase = .turnIntro
    }

    private mutating func advanceToNextPlayer() {
        let n = players.count
        for step in 1...n {
            let j = (currentIndex + step) % n
            if !players[j].isOut {
                currentIndex = j
                return
            }
        }
    }

    /// Meiste Stimmen fliegt. Bei Gleichstand: mehr falsche Antworten in der Runde,
    /// dann weniger richtige, dann Zufall.
    private mutating func tallyVotes() -> VoteResult {
        var tally: [UUID: Int] = [:]
        for p in activePlayers { tally[p.id] = 0 }
        for candidate in votes.values { tally[candidate, default: 0] += 1 }
        let maxVotes = tally.values.max() ?? 0
        var tied = activePlayers.filter { tally[$0.id] == maxVotes }
        let wasTieBreak = tied.count > 1
        if tied.count > 1, let maxWrong = tied.map(\.roundWrong).max() {
            tied = tied.filter { $0.roundWrong == maxWrong }
        }
        if tied.count > 1, let minCorrect = tied.map(\.roundCorrect).min() {
            tied = tied.filter { $0.roundCorrect == minCorrect }
        }
        let loser = tied.count == 1 ? tied[0] : tied.randomElement(using: &rng)!
        return VoteResult(playerID: loser.id, tally: tally, wasTieBreak: wasTieBreak)
    }
}
