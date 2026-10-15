import Foundation
import Testing
@testable import DDF

private func question(_ id: String, category: String = "Test", difficulty: Int = 1) -> Question {
    Question(id: id, category: category, difficulty: difficulty, text: "Frage \(id)?",
             answer: "Richtig", wrongAnswers: ["A", "B", "C"])
}

private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "ddf.tests.\(UUID().uuidString)")!
}

struct QuestionPoolTests {
    @Test func unseenQuestionsComeFirst() {
        let questions = (0..<10).map { question("q\($0)") }
        let seen = Set((0..<7).map { "q\($0)" })
        var rng = SplitMix64(seed: 4)
        var deck = QuestionDeck(questions: questions, answerMode: .host, seen: seen, rng: &rng)
        let firstThree = (0..<3).compactMap { _ in deck.draw(progress: 0, rng: &rng)?.id }
        #expect(Set(firstThree) == ["q7", "q8", "q9"])
        // Danach kommen die schon gesehenen.
        #expect(seen.contains(deck.draw(progress: 0, rng: &rng)!.id))
    }

    @MainActor @Test func excludedCategoriesLeaveThePool() {
        let questions = [question("a", category: "Sport"), question("b", category: "Musik"), question("c", category: "Musik")]
        let model = AppModel(defaults: freshDefaults(), questions: questions)
        model.setCategory("Musik", enabled: false)
        #expect(model.questionPool.map(\.id) == ["a"])
        model.setAllCategories(enabled: false)
        #expect(model.questionPool.isEmpty)
        model.addPlayer(named: "Mia")
        model.addPlayer(named: "Tom")
        #expect(!model.canStart)
        model.setAllCategories(enabled: true)
        #expect(model.questionPool.count == 3)
    }

    @MainActor @Test func shownQuestionsAreRememberedAcrossLaunches() {
        let defaults = freshDefaults()
        let model = AppModel(defaults: defaults, questions: (0..<6).map { question("q\($0)") })
        model.addPlayer(named: "Mia")
        model.addPlayer(named: "Tom")
        model.addPlayer(named: "Ali")
        model.startGame()
        model.session?.startTurn()
        guard case .asking(let turn) = model.session?.phase else { Issue.record("Keine Frage"); return }
        #expect(model.seenQuestionIDs.contains(turn.question.id))
        let reopened = AppModel(defaults: defaults, questions: (0..<6).map { question("q\($0)") })
        #expect(reopened.seenQuestionIDs.contains(turn.question.id))
    }

    @MainActor @Test func everythingSeenStartsOver() {
        let defaults = freshDefaults()
        let questions = (0..<3).map { question("q\($0)") }
        let model = AppModel(defaults: defaults, questions: questions)
        model.addPlayer(named: "Mia")
        model.addPlayer(named: "Tom")
        model.addPlayer(named: "Ali")
        for _ in 0..<3 {
            model.startGame()
            model.session?.startTurn()
            model.endGame()
        }
        #expect(model.seenQuestionIDs.count == 3)
        model.startGame()
        #expect(model.seenQuestionIDs.isEmpty)
    }

    @MainActor @Test func reportsAreSavedAndShareable() {
        let defaults = freshDefaults()
        let q = question("x1", category: "Sprache")
        let model = AppModel(defaults: defaults, questions: [q])
        model.report(q, reason: .wrong)
        model.report(q, reason: .wrong)
        model.report(q, reason: .unclear)
        #expect(model.reports.count == 2)
        #expect(model.reportsText.contains("x1"))
        let reopened = AppModel(defaults: defaults, questions: [q])
        #expect(reopened.reports.count == 2)
        reopened.clearReports()
        #expect(reopened.reports.isEmpty)
    }

    @Test func oldSettingsWithoutCategoriesStillDecode() throws {
        let json = #"{"lives":2,"answerTime":10}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(GameSettings.self, from: json)
        #expect(settings.excludedCategories.isEmpty)
        #expect(settings.lives == 2)
    }
}
