import Foundation
import Testing
@testable import DDF

private func makeQuestions(_ count: Int = 30) -> [Question] {
    (0..<count).map { i in
        Question(id: "t\(i)", category: "Test", difficulty: i % 3 + 1, text: "Frage \(i)?",
                 answer: "Richtig \(i)", wrongAnswers: ["A\(i)", "B\(i)", "C\(i)"])
    }
}

private func makePlayers(_ count: Int) -> [Player] {
    (0..<count).map { Player(name: "P\($0)", colorIndex: $0) }
}

/// Spielt eine Frage für den aktuellen Spieler durch.
private func play(_ engine: inout GameEngine, _ outcome: AnswerOutcome) {
    engine.startTurn()
    engine.answer(outcome)
    engine.continueAfterFeedback()
}

struct GameEngineTests {
    @Test func wrongAnswerCostsLifeInLivesMode() {
        var settings = GameSettings()
        settings.lives = 2
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 1)
        let first = engine.currentPlayer.id
        engine.startTurn()
        engine.answer(.wrong)
        guard case .feedback(let result) = engine.phase else { Issue.record("Kein Feedback"); return }
        #expect(result.lostLife)
        #expect(result.livesLeft == 1)
        engine.continueAfterFeedback()
        #expect(engine.phase == .turnIntro)
        #expect(engine.currentPlayer.id != first)
    }

    @Test func eliminatedPlayerIsSkipped() {
        var settings = GameSettings()
        settings.lives = 1
        var engine = GameEngine(players: makePlayers(4), settings: settings, questions: makeQuestions(), seed: 2)
        let loser = engine.currentPlayer.id
        play(&engine, .wrong)
        #expect(engine.phase == .elimination(loser))
        engine.continueAfterElimination()
        for _ in 0..<6 {
            #expect(engine.currentPlayer.id != loser)
            play(&engine, .correct)
        }
    }

    @Test func lastTwoPlayFinaleWithFreshLives() {
        var settings = GameSettings()
        settings.lives = 1
        settings.finaleLives = 2
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 3)
        play(&engine, .wrong)
        engine.continueAfterElimination()
        #expect(engine.phase == .finaleIntro)
        engine.startFinale()
        #expect(engine.isFinale)
        #expect(engine.activePlayers.allSatisfy { $0.lives == 2 })
        // Der aktuelle Spieler verliert beide Leben, der andere gewinnt.
        let loser = engine.currentPlayer.id
        play(&engine, .wrong)
        play(&engine, .correct)
        #expect(engine.currentPlayer.id == loser)
        play(&engine, .wrong)
        guard case .elimination = engine.phase else { Issue.record("Kein Rauswurf"); return }
        engine.continueAfterElimination()
        guard case .winner(let winner) = engine.phase else { Issue.record("Kein Sieger"); return }
        #expect(winner != loser)
        #expect(engine.ranking.first?.id == winner)
    }

    @Test func twoPlayersStartDirectlyInFinale() {
        let engine = GameEngine(players: makePlayers(2), settings: GameSettings(), questions: makeQuestions(), seed: 4)
        #expect(engine.phase == .finaleIntro)
    }

    @Test func voteModeKeepsLivesAndEndsRoundAfterCurrentQuestion() {
        var settings = GameSettings()
        settings.eliminationMode = .vote
        settings.lives = 1
        var engine = GameEngine(players: makePlayers(4), settings: settings, questions: makeQuestions(), seed: 5)
        engine.startTurn()
        engine.answer(.wrong)
        #expect(engine.currentPlayer.lives == 1)
        engine.markRoundTimeUp()
        #expect({ if case .feedback = engine.phase { return true } else { return false } }())
        engine.continueAfterFeedback()
        #expect(engine.phase == .roundOver)
    }

    @Test func votingEliminatesMostVotedAndBlocksSelfVotes() {
        var settings = GameSettings()
        settings.eliminationMode = .vote
        settings.lives = 1
        var engine = GameEngine(players: makePlayers(4), settings: settings, questions: makeQuestions(), seed: 6)
        engine.markRoundTimeUp()
        #expect(engine.phase == .roundOver)
        engine.beginVoting()
        let target = engine.voters[3].id
        // Wähler 0 versucht sich selbst zu wählen: wird ignoriert.
        engine.castVote(for: engine.voters[0].id)
        #expect(engine.phase == .voting(voterIndex: 0))
        engine.castVote(for: target)
        engine.castVote(for: target)
        engine.castVote(for: target)
        engine.castVote(for: engine.voters[0].id)
        guard case .voteResult(let result) = engine.phase else { Issue.record("Kein Ergebnis"); return }
        #expect(result.playerID == target)
        #expect(result.tally[target] == 3)
        engine.continueAfterVoteResult()
        #expect(engine.phase == .elimination(target))
        engine.continueAfterElimination()
        #expect(engine.phase == .turnIntro)
        #expect(engine.round == 2)
    }

    @Test func tieIsBrokenByWrongAnswersInRound() {
        var settings = GameSettings()
        settings.eliminationMode = .vote
        var engine = GameEngine(players: makePlayers(4), settings: settings, questions: makeQuestions(), seed: 7)
        let order = engine.players.map(\.id)
        // P0 richtig, P1 falsch, P2 richtig, P3 richtig.
        play(&engine, .correct)
        play(&engine, .wrong)
        play(&engine, .correct)
        play(&engine, .correct)
        engine.markRoundTimeUp()
        engine.beginVoting()
        // Je zwei Stimmen für P0 und P1.
        engine.castVote(for: order[1])
        engine.castVote(for: order[0])
        engine.castVote(for: order[0])
        engine.castVote(for: order[1])
        guard case .voteResult(let result) = engine.phase else { Issue.record("Kein Ergebnis"); return }
        #expect(result.wasTieBreak)
        #expect(result.playerID == order[1])
    }

    @Test func multipleChoiceChecksAnswer() {
        var settings = GameSettings()
        settings.answerMode = .multipleChoice
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 8)
        engine.startTurn()
        guard case .asking(let turn) = engine.phase, let correct = turn.correctOptionIndex else {
            Issue.record("Keine Optionen"); return
        }
        #expect(turn.options.count == 4)
        engine.choose(option: correct)
        guard case .feedback(let result) = engine.phase else { Issue.record("Kein Feedback"); return }
        #expect(result.outcome == .correct)
    }

    @Test func deckDoesNotRepeatUntilExhausted() {
        var rng = SplitMix64(seed: 9)
        let questions = makeQuestions(12)
        var deck = QuestionDeck(questions: questions, answerMode: .host, rng: &rng)
        var seen = Set<String>()
        for i in 0..<12 {
            let q = deck.draw(progress: Double(i) / 12, rng: &rng)
            #expect(q != nil)
            #expect(seen.insert(q!.id).inserted)
        }
        #expect(deck.draw(progress: 0.5, rng: &rng) != nil)
    }

    @Test func trueFalseOffersTwoOptions() {
        var settings = GameSettings()
        settings.answerMode = .multipleChoice
        let statement = Question(id: "tf", category: "Test", difficulty: 1, text: "Deutschland liegt in Asien.",
                                 answer: Question.falseAnswer, wrongAnswers: [Question.trueAnswer])
        #expect(statement.isTrueFalse && statement.supportsMultipleChoice)
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: [statement], seed: 3)
        engine.startTurn()
        guard case .asking(let turn) = engine.phase else { Issue.record("Keine Frage"); return }
        #expect(turn.options == [Question.trueAnswer, Question.falseAnswer])
        engine.choose(option: 0)
        guard case .feedback(let result) = engine.phase else { Issue.record("Kein Feedback"); return }
        #expect(result.outcome == .wrong)
    }

    @Test func bundledQuestionsAreValid() {
        let questions = QuestionBank.loadAll(bundle: Bundle.main)
        #expect(questions.count >= 1000)
        #expect(Set(questions.map(\.id)).count == questions.count)
        #expect(Set(questions.map(\.category)).count >= 10)
        #expect(questions.contains { $0.isTrueFalse })
        for q in questions {
            #expect(q.supportsMultipleChoice, "\(q.id) hat zu wenige falsche Antworten")
            #expect(!q.wrongAnswers.contains(q.answer), "\(q.id) hat die Antwort unter den falschen")
            #expect((1...3).contains(q.difficulty), "\(q.id) hat keine gültige Schwierigkeit")
        }
    }
}


@MainActor
struct GameSessionLimitTests {
    @Test func noAnswerTimeMeansNoCountdown() {
        var settings = GameSettings()
        settings.answerTime = 0
        let session = GameSession(players: makePlayers(3), settings: settings, questions: makeQuestions())
        session.startTurn()
        guard case .asking = session.phase else { Issue.record("Frage sollte laufen"); return }
        #expect(session.turnDeadline == nil)
        session.end()
    }

    @Test func roundWithoutLimitEndsManually() {
        var settings = GameSettings()
        settings.eliminationMode = .vote
        settings.roundDuration = 0
        let session = GameSession(players: makePlayers(3), settings: settings, questions: makeQuestions())
        session.startTurn()
        #expect(session.roundDeadline == nil)
        #expect(session.canEndRoundManually)
        session.endRoundManually()
        #expect(!session.canEndRoundManually)
        session.answer(.correct)
        session.continueAfterFeedback()
        #expect(session.phase == .roundOver)
        session.end()
    }

    @Test func voteRoundSkipsTurnIntroAfterFirstQuestion() {
        var settings = GameSettings()
        settings.eliminationMode = .vote
        let session = GameSession(players: makePlayers(3), settings: settings, questions: makeQuestions())
        session.startTurn()
        let first = session.engine.currentPlayer.id
        session.answer(.correct)
        session.continueAfterFeedback()
        guard case .asking = session.phase else {
            Issue.record("Erwartet: direkt die nächste Frage, war \(session.phase)")
            return
        }
        #expect(session.engine.currentPlayer.id != first)
        session.end()
    }

    @Test func livesModeStillShowsTurnIntro() {
        let session = GameSession(players: makePlayers(3), settings: GameSettings(), questions: makeQuestions())
        session.startTurn()
        session.answer(.correct)
        session.continueAfterFeedback()
        #expect(session.phase == .turnIntro)
        session.end()
    }

    @MainActor @Test func lastGroupCanBeRestored() {
        let defaults = UserDefaults(suiteName: "ddf.tests.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults, questions: makeQuestions(5))
        model.addPlayer(named: "Mia")
        model.addPlayer(named: "Tom")
        #expect(!model.canRestoreLastGroup)
        model.startGame()
        model.endGame()
        model.removeAllPlayers()
        #expect(model.canRestoreLastGroup)
        model.restoreLastGroup()
        #expect(model.players.map(\.name) == ["Mia", "Tom"])
        #expect(!model.canRestoreLastGroup)
        // Bleibt nach einem Neustart der App erhalten.
        let reloaded = AppModel(defaults: defaults, questions: makeQuestions(5))
        #expect(reloaded.lastGroup.map(\.name) == ["Mia", "Tom"])
    }

    @MainActor @Test func eliminationAnimationsRotate() {
        var seen: [EliminationStyle] = []
        for _ in 0..<(EliminationStyle.allCases.count * 3) { seen.append(EliminationStyle.next()) }
        // Nie zweimal dieselbe hintereinander, und in jeder Runde von fünf kommt jede einmal.
        #expect(zip(seen, seen.dropFirst()).allSatisfy { $0 != $1 })
        let n = EliminationStyle.allCases.count
        for round in 0..<3 {
            #expect(Set(seen[(round * n)..<((round + 1) * n)]).count == n)
        }
    }

    @Test func manyLivesAreKept() {
        var settings = GameSettings()
        settings.lives = 50
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 9)
        play(&engine, .wrong)
        #expect(engine.players.contains { $0.lives == 49 })
    }
}

struct NewFeatureTests {
    @Test func handicapShiftsDifficulty() {
        var rng = SplitMix64(seed: 3)
        var deck = QuestionDeck(questions: makeQuestions(30), answerMode: .host, rng: &rng)
        // Spielbeginn wäre Stufe 1, mit +1 wird es Stufe 2, mit +2 bleibt es bei der höchsten Stufe 3.
        #expect(deck.draw(progress: 0, handicap: 1, rng: &rng)?.difficulty == 2)
        #expect(deck.draw(progress: 0, handicap: 5, rng: &rng)?.difficulty == 3)
        #expect(deck.draw(progress: 1, handicap: -1, rng: &rng)?.difficulty == 2)
    }

    @Test func historyRecordsAnswers() {
        var engine = GameEngine(players: makePlayers(3), settings: GameSettings(), questions: makeQuestions(), seed: 11)
        play(&engine, .wrong)
        play(&engine, .correct)
        #expect(engine.history.count == 2)
        #expect(engine.history.first?.outcome == .wrong)
    }

    @Test func oldSettingsStillDecode() throws {
        let json = #"{"lives":4,"answerTime":20,"eliminationMode":"lives","roundDuration":180,"answerMode":"host","finaleLives":2}"#
        let s = try JSONDecoder().decode(GameSettings.self, from: Data(json.utf8))
        #expect(s.lives == 4 && s.finaleLives == 2)
    }

    @Test func oldPlayersStillDecode() throws {
        let json = #"[{"id":"7B1B0C4E-1D2A-4C55-9C2A-1A1A1A1A1A1A","name":"Mia","colorIndex":2}]"#
        let players = try JSONDecoder().decode([Player].self, from: Data(json.utf8))
        #expect(players.first?.handicap == 0)
    }
}
