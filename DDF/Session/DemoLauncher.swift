#if DEBUG
import Foundation

/// Startet die App direkt in einer Spielphase, z. B. mit dem Startargument `-demo elimination`.
/// Gedacht für Design-Reviews und Screenshots, nicht im Release-Build enthalten.
@MainActor
enum DemoLauncher {
    /// Die gewünschte Szene aus `-demo <szene>`.
    static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func apply(to model: AppModel) {
        guard let scene, !["wabbel", "brand", "splash"].contains(scene) else { return }
        model.players = ["Lena", "Murat", "Jonas", "Aylin", "Paul", "Sophie"].enumerated()
            .map { Player(name: $1, colorIndex: $0) }
        var settings = GameSettings()
        switch scene {
        case "mc", "tf": settings.answerMode = .multipleChoice
        case "vote", "ballot", "voteresult": settings.eliminationMode = .vote
        case "elimination": settings.lives = 1
        case "finale", "winner", "duel": settings.lives = 1
        default: break
        }
        model.settings = settings
        guard scene != "home" else { return }
        model.startGame()
        guard let session = model.session else { return }

        switch scene {
        case "question", "mc":
            session.startTurn()
        case "hosttf":
            for _ in 0..<200 {
                session.startTurn()
                if case .asking(let turn) = session.engine.phase, turn.question.isTrueFalse { break }
                session.answer(.correct)
                session.continueAfterFeedback()
            }
            session.choose(option: 1)
        case "tf":
            // Richtig beantworten, bis eine Wahr-oder-falsch-Aussage kommt.
            for _ in 0..<200 {
                session.startTurn()
                if case .asking(let turn) = session.engine.phase, turn.question.isTrueFalse { break }
                session.answer(.correct)
                session.continueAfterFeedback()
            }
        case "feedback":
            session.startTurn()
            session.answer(.wrong)
        case "correct":
            session.startTurn()
            session.answer(.correct)
        case "elimination":
            session.startTurn()
            session.answer(.wrong)
            session.continueAfterFeedback()
        case "vote":
            session.debugEndRound()
        case "ballot":
            session.debugEndRound()
            session.beginVoting()
        case "voteresult":
            session.debugEndRound()
            session.beginVoting()
            for index in session.engine.voters.indices {
                let target = session.engine.candidates(forVoterAt: index).first!.id
                session.castVote(for: target)
            }
        case "finale", "winner", "duel":
            while session.engine.activePlayers.count > 2 {
                session.startTurn()
                session.answer(.wrong)
                session.continueAfterFeedback()
                session.continueAfterElimination()
            }
            if scene == "duel" {
                session.startFinale()
                session.startTurn()
            }
            if scene == "winner" {
                session.startFinale()
                for _ in 0..<(settings.finaleLives) {
                    session.startTurn()
                    session.answer(.wrong)
                    session.continueAfterFeedback()
                    if case .elimination = session.phase { break }
                    session.startTurn()
                    session.answer(.correct)
                    session.continueAfterFeedback()
                }
                session.continueAfterElimination()
            }
        default:
            break
        }
    }
}
#endif
