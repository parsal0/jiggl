import SwiftUI

/// Schaltet je nach Spielphase den passenden Screen ein.
struct GameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: GameSession
    @State private var showMenu = false
    /// Während Wabbel den Screen verdeckt, bleibt die alte Phase stehen.
    @State private var frozenPhase: Phase?
    @State private var curtainStart: Date?

    private var phase: Phase { frozenPhase ?? session.phase }

    var body: some View {
        ZStack {
            // Grundfarbe = Farbe des aktuellen Screens. So blitzt beim Wechsel nie Weiß an den Rändern auf.
            backdrop.ignoresSafeArea()
            content
        }
        .onChange(of: session.phase) { old, new in
            guard Self.usesCurtain(new), !reduceMotion else { return }
            frozenPhase = old
            runCurtain()
        }
        // Anruf, Sperrbildschirm, Kontrollzentrum: Die Zeit darf nicht weiterlaufen.
        .onChange(of: scenePhase) { _, new in
            guard new != .active, session.pauseForBackground() else { return }
            showMenu = true
        }
        .onAppear {
            guard !reduceMotion else { return }
            // Spielstart: Wabbel verdeckt schon alles und hüpft raus.
            curtainStart = Date().addingTimeInterval(-WabbelCurtain.coverTime)
            Task {
                try? await Task.sleep(for: .seconds(WabbelCurtain.duration))
                curtainStart = nil
            }
        }
        .overlay(alignment: .top) { hud }
        .overlay {
            if showMenu {
                PauseMenu(
                    canEndRound: session.canEndRoundManually,
                    resume: { showMenu = false; session.resume() },
                    endRound: { showMenu = false; session.resume(); session.endRoundManually() },
                    restart: { showMenu = false; model.restartWithSamePlayers() },
                    quit: { showMenu = false; model.endGame() }
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMenu)
        .overlay { curtain }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private var content: some View {
        if let (turn, result) = questionState {
            // Die Frage geht vom Knopf „Frage zeigen“ aus auf.
            QuestionView(session: session, turn: turn, result: result)
                .id(turn.number)
                .zIndex(layer)
                .transition(.reveal(from: UnitPoint(x: 0.5, y: 0.94), reduceMotion: reduceMotion))
        } else {
            switch phase {
            case .turnIntro:
                TurnIntroView(session: session)
                    .id("intro-\(session.engine.questionNumber)")
                    .zIndex(layer)
                    .transition(.reveal(from: .center, reduceMotion: reduceMotion))
            case .roundOver:
                RoundOverView(session: session).zIndex(layer).transition(.opacity)
            case .voting(let index):
                VotingView(session: session, voterIndex: index)
                    .id("vote-\(index)")
                    .zIndex(layer)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .voteResult(let result):
                VoteResultView(session: session, result: result).zIndex(layer).transition(.opacity)
            case .elimination(let id):
                EliminationView(session: session, playerID: id).zIndex(layer).transition(.opacity)
            case .finaleIntro:
                FinaleIntroView(session: session).zIndex(layer).transition(.opacity)
            case .winner(let id):
                WinnerView(session: session, playerID: id).zIndex(layer).transition(.opacity)
            case .asking, .feedback:
                EmptyView()
            }
        }
    }

    /// Neuere Screens liegen beim Übergang über älteren.
    private var layer: Double { Double(session.engine.step) }

    private var backdrop: Color {
        switch phase {
        case .turnIntro: Q.playerColor(session.engine.currentPlayer.player.colorIndex)
        case .asking(let turn): Q.categoryColor(turn.question.category)
        case .feedback(let result):
            switch result.outcome {
            case .correct: Q.correct
            case .wrong: Q.wrong
            case .timeout: Q.orange
            }
        case .roundOver: Q.orange
        case .voting(let index):
            session.engine.voters.indices.contains(index) ? Q.playerColor(session.engine.voters[index].player.colorIndex) : Q.blue
        case .voteResult: Q.blue
        case .elimination: Q.pink
        case .finaleIntro: Q.purple
        case .winner: Q.yellow
        }
    }

    /// Große Momente bekommen Wabbel als Vorhang, normale Züge nicht.
    private static func usesCurtain(_ phase: Phase) -> Bool {
        switch phase {
        case .roundOver, .finaleIntro, .winner: true
        default: false
        }
    }

    private func runCurtain() {
        curtainStart = Date()
        Task {
            try? await Task.sleep(for: .seconds(WabbelCurtain.coverTime))
            frozenPhase = nil
            try? await Task.sleep(for: .seconds(WabbelCurtain.duration - WabbelCurtain.coverTime))
            curtainStart = nil
        }
    }

    @ViewBuilder private var curtain: some View {
        if let curtainStart {
            TimelineView(.animation) { context in
                WabbelCurtain(t: context.date.timeIntervalSince(curtainStart))
            }
        }
    }

    /// Frage und Auflösung teilen sich einen Screen, damit die Animation durchläuft.
    private var questionState: (Turn, TurnResult?)? {
        switch phase {
        case .asking(let turn): return (turn, nil)
        case .feedback(let result): return (result.turn, result)
        default: return nil
        }
    }

    private var showsHUD: Bool {
        if case .winner = phase { return false }
        return true
    }

    @ViewBuilder private var hud: some View {
        if showsHUD {
            HStack(spacing: 8) {
                RoundClock(session: session)
                Spacer()
                if session.canEndRoundManually {
                    Button("Runde beenden") { session.endRoundManually() }
                        .font(.qBody(14, .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Capsule().fill(Q.ink))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
                Button {
                    session.pause()
                    showMenu = true
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(QIconButtonStyle(size: 44))
                .accessibilityLabel("Pause")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }
}

/// Rundenuhr im Abstimmungs-Modus, sonst die Fragennummer.
struct RoundClock: View {
    let session: GameSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            Group {
                if session.engine.isFinale {
                    label("Finale", fill: Q.pink, foreground: .white)
                } else if let remaining = session.roundRemaining(at: context.date) {
                    let s = Int(remaining.rounded(.up))
                    label(String(format: "Runde %d · %d:%02d", session.engine.round, s / 60, s % 60),
                          fill: remaining < 20 ? Q.red : Q.surface,
                          foreground: remaining < 20 ? .white : Q.ink)
                } else if session.engine.roundTimeUp {
                    label(session.settings.hasRoundTimer ? "Zeit ist um" : "Letzte Frage", fill: Q.red, foreground: .white)
                } else if session.engine.isVoteRoundRunning, !session.settings.hasRoundTimer {
                    label("Runde \(session.engine.round) · ohne Limit", fill: Q.surface, foreground: Q.ink)
                } else {
                    label("Frage \(max(session.engine.questionNumber, 1))", fill: Q.surface, foreground: Q.ink)
                }
            }
        }
    }

    private func label(_ text: String, fill: Color, foreground: Color) -> some View {
        Text(text)
            .font(.qBody(15, .heavy))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Capsule().fill(fill))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

struct PauseMenu: View {
    var canEndRound = false
    var resume: () -> Void
    var endRound: () -> Void = {}
    var restart: () -> Void
    var quit: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Nur einblenden, nicht skalieren: Sonst flackern oben und unten die Ränder.
            Q.ink.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: resume)
            VStack(spacing: 12) {
                Text("Pause").font(.q(44)).foregroundStyle(Q.ink).padding(.bottom, 8)
                Button("Weiter", action: resume).buttonStyle(QButtonStyle())
                if canEndRound {
                    Button("Runde beenden und abstimmen", action: endRound)
                        .buttonStyle(QButtonStyle(fill: Q.pink, fontSize: 18))
                }
                Button("Neu starten", action: restart).buttonStyle(QButtonStyle(fill: Q.bg, foreground: Q.ink, fontSize: 20))
                Button("Spiel beenden", action: quit).buttonStyle(QButtonStyle(fill: Q.red, fontSize: 20))
            }
            .padding(24)
            .card(radius: 32)
            .overlay(alignment: .topTrailing) {
                WabbelView(mood: .sleep, size: 92).offset(x: -14, y: -78)
            }
            .padding(28)
            .scaleEffect(appeared ? 1 : 0.92)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appeared)
            .onAppear { appeared = true }
        }
    }
}
