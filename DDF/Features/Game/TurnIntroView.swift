import SwiftUI

/// „Lena ist dran!“: Lenas Wabbel in ihrer Farbe hält ein Schild mit ihrem Namen über den Kopf.
struct TurnIntroView: View {
    let session: GameSession
    @State private var slammed = false
    @State private var drumBeat = 0
    /// Nach dem ersten Zug nicht immer derselbe Trommelwirbel.
    @State private var style: IntroStyle?

    enum IntroStyle: CaseIterable {
        /// Langer Trommelwirbel: erster Zug und Finale.
        case drumroll
        /// Kurzer Wirbel.
        case quickDrum
        /// Wabbel winkt den Nächsten ran.
        case wave
        /// Drei Schläge mit dem Richterhammer.
        case gavel

        private static var last: IntroStyle?

        static func next(firstTurn: Bool, finale: Bool) -> IntroStyle {
            if firstTurn || finale { return .drumroll }
            let options: [IntroStyle] = [.quickDrum, .wave, .gavel]
            let pick = options.filter { $0 != last }.randomElement() ?? .quickDrum
            last = pick
            return pick
        }
    }

    var body: some View {
        let state = session.engine.currentPlayer
        let player = state.player
        let color = Q.playerColor(player.colorIndex)
        let maxLives = session.engine.isFinale ? session.settings.finaleLives : session.settings.lives
        let fg = Q.onPlayerColor(player.colorIndex)

        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Der Wabbel des Spielers in seiner Farbe. Erst trommelt, winkt oder klopft er,
            // dann reißt er ein Schild mit dem Namen an zwei Stangen über den Kopf.
            ZStack {
                Circle().fill(.white).frame(width: 270, height: 270)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    .offset(y: 34)
                WabbelView(mood: slammed ? .holdSign : waitingMood, size: 205, playerColor: player.colorIndex,
                           sign: player.name, signColor: player.colorIndex == 7 ? Q.ink : color)
                    .allowsHitTesting(false)
                    .accessibilityLabel(player.name)
            }
            .padding(.top, 80)
            .padding(.bottom, 24)

            StickerLabel(text: "ist dran!", fill: .white, foreground: color, size: 30, tilt: -4)
                .scaleEffect(slammed ? 1 : 2)
                .opacity(slammed ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.52).delay(0.18), value: slammed)

            Group {
                if session.engine.isFinale {
                    DuelBar(session: session).padding(.horizontal, 20)
                } else if session.engine.wrongAnswersCostLives {
                    HeartsRow(lives: state.lives, maxLives: maxLives, size: 30)
                } else {
                    Text("\(state.roundCorrect) richtig · \(state.roundWrong) falsch")
                        .font(.qBody(18, .bold))
                        .foregroundStyle(fg.opacity(0.85))
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 8)

            Text(instruction)
                .font(.qBody(17, .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(fg.opacity(0.85))
                .padding(.horizontal, 30)
                .padding(.bottom, 16)

            Button("Frage zeigen") { session.startTurn() }
                .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .heavy), trigger: slammed)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: drumBeat)
        .task {
            let style = IntroStyle.next(firstTurn: session.engine.questionNumber == 0, finale: session.engine.isFinale)
            self.style = style
            switch style {
            case .drumroll, .quickDrum:
                for _ in 0..<(style == .drumroll ? 11 : 5) {
                    try? await Task.sleep(for: .milliseconds(70))
                    drumBeat += 1
                }
            case .wave:
                try? await Task.sleep(for: .milliseconds(380))
            case .gavel:
                for _ in 0..<3 {
                    try? await Task.sleep(for: .milliseconds(160))
                    drumBeat += 1
                }
            }
            guard !Task.isCancelled else { return }
            slammed = true
        }
    }

    private var waitingMood: WabbelView.Mood {
        switch style {
        case .wave: .wave
        case .gavel: .judge
        case .drumroll, .quickDrum, nil: .drumroll
        }
    }

    private var instruction: String {
        let name = session.engine.currentPlayer.player.name
        switch session.settings.answerMode {
        case .host: return "Spielleiter: Lies \(name) die Frage laut vor."
        case .multipleChoice: return "Gib das Handy an \(name)."
        }
    }
}
