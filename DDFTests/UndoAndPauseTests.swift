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

struct UndoTests {
    @Test func undoRestoresLifeAndReopensQuestion() {
        var settings = GameSettings()
        settings.lives = 2
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 21)
        let id = engine.currentPlayer.id
        engine.startTurn()
        guard case .asking(let turn) = engine.phase else { Issue.record("Keine Frage"); return }
        engine.answer(.wrong)
        #expect(engine.player(id)?.lives == 1)
        #expect(engine.canUndoAnswer)

        engine.undoAnswer()
        #expect(engine.phase == .asking(turn))
        #expect(engine.player(id)?.lives == 2)
        #expect(engine.player(id)?.totalWrong == 0)
        #expect(engine.history.isEmpty)
        #expect(!engine.canUndoAnswer)

        engine.answer(.correct)
        #expect(engine.player(id)?.totalCorrect == 1)
        #expect(engine.history.count == 1)
    }

    @Test func undoPreventsWrongElimination() {
        var settings = GameSettings()
        settings.lives = 1
        var engine = GameEngine(players: makePlayers(3), settings: settings, questions: makeQuestions(), seed: 22)
        engine.startTurn()
        engine.answer(.wrong)
        engine.undoAnswer()
        engine.answer(.correct)
        engine.continueAfterFeedback()
        #expect(engine.phase == .turnIntro)
        #expect(engine.activePlayers.count == 3)
    }

    @Test func noUndoAfterContinuing() {
        var engine = GameEngine(players: makePlayers(3), settings: GameSettings(), questions: makeQuestions(), seed: 23)
        engine.startTurn()
        engine.answer(.wrong)
        engine.continueAfterFeedback()
        #expect(!engine.canUndoAnswer)
        let before = engine.phase
        engine.undoAnswer()
        #expect(engine.phase == before)
    }
}

@MainActor
struct BackgroundPauseTests {
    private func session(answerTime: Int) -> GameSession {
        var settings = GameSettings()
        settings.answerTime = answerTime
        return GameSession(players: makePlayers(3), settings: settings, questions: makeQuestions())
    }

    @Test func backgroundFreezesAnswerTimer() async throws {
        let session = session(answerTime: 1)
        session.startTurn()
        #expect(session.pauseForBackground())
        #expect(session.isPaused)
        let frozen = session.turnRemaining(at: Date())

        // Länger als die Antwortzeit warten: Die Frage darf nicht ablaufen.
        try await Task.sleep(for: .milliseconds(1400))
        guard case .asking = session.phase else { Issue.record("Zeit lief im Hintergrund ab"); return }
        #expect(session.turnRemaining(at: Date().addingTimeInterval(10)) == frozen)

        session.resume()
        #expect(!session.isPaused)
        #expect(session.turnRemaining(at: Date()) <= frozen)
    }

    @Test func backgroundPausesOnlyOnce() {
        let session = session(answerTime: 15)
        session.startTurn()
        #expect(session.pauseForBackground())
        #expect(!session.pauseForBackground())
    }

    @Test func undoRestartsAnswerTimer() {
        let session = session(answerTime: 15)
        session.startTurn()
        session.answer(.wrong)
        session.undoAnswer()
        guard case .asking = session.phase else { Issue.record("Frage nicht wieder offen"); return }
        #expect(session.turnDeadline != nil)
        #expect(session.turnRemaining(at: Date()) > 14)
    }
}
