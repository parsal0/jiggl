import SwiftUI

/// Duell der letzten zwei.
struct FinaleIntroView: View {
    let session: GameSession
    @State private var start = Date()

    var body: some View {
        let finalists = session.engine.activePlayers
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            VStack(spacing: 0) {
                StickerLabel(text: "Finale!", fill: Q.yellow, foreground: Q.ink, size: 72, tilt: -5)
                    .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0.1, 0.5), overshoot: 2.2)))
                    .padding(.top, 100)

                Spacer()

                if finalists.count == 2 {
                    VStack(spacing: 18) {
                        PlayerChip(player: finalists[0].player, size: 26, tilt: -4)
                            .offset(x: -420 * (1 - Ease.outCubic(Ease.segment(t, 0.5, 0.85))))
                        Text("VS")
                            .font(.q(34))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(Q.ink))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 5))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            .scaleEffect(Ease.outBack(Ease.segment(t, 0.85, 1.1)))
                            .rotationEffect(.degrees(8 + Ease.wobble(Ease.segment(t, 1.1, 2.0)) * 12))
                        PlayerChip(player: finalists[1].player, size: 26, tilt: 3)
                            .offset(x: 420 * (1 - Ease.outCubic(Ease.segment(t, 0.6, 0.95))))
                    }
                }

                Spacer()

                // Wabbel im Scheinwerferlicht: erst Trommelwirbel, dann „Tadaa!“.
                WabbelView(mood: t < 1.1 ? .drumroll : .present, size: 96)
                    .background(alignment: .bottom) {
                        Spotlight()
                            .frame(width: 220, height: 900)
                            .offset(y: 18)
                            .opacity(Ease.segment(t, 0.2, 0.6))
                    }
                    .padding(.bottom, 8)

                Text("Jeder hat \(session.settings.finaleLives) Leben. Wer zuerst keins mehr hat, ist der Dümmste.")
                    .font(.qBody(17, .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .opacity(Ease.segment(t, 1.1, 1.4))

                Button("Los!") { session.startFinale() }
                    .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
                    .padding(.bottom, 12)
                    .opacity(Ease.segment(t, 1.2, 1.5))
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Q.purple.ignoresSafeArea())
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: start)
        .onAppear { start = Date() }
    }
}

struct WinnerView: View {
    @Environment(AppModel.self) private var model
    let session: GameSession
    let playerID: UUID
    @State private var start = Date()
    @State private var showDumbest = false
    @State private var crowned = false

    /// Krone fliegt im Bogen von Wabbels Händen auf den Kopf des Siegers und federt nach.
    private func crown(_ t: Double) -> some View {
        let e = Ease.inOutCubic(Ease.segment(t, 0.9, 1.35))
        let from = CGPoint(x: 118, y: -36), to = CGPoint(x: -20, y: -64)
        let bounce = Ease.wobble(Ease.segment(t, 1.35, 2.0), frequency: 2.5, decay: 4)
        return Image(systemName: "crown.fill")
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .rotationEffect(.degrees(-12 * e + 360 * e))
            .scaleEffect(1 + 0.3 * bounce)
            .offset(x: from.x + (to.x - from.x) * e, y: from.y + (to.y - from.y) * e - 110 * sin(e * .pi))
            .onChange(of: t > 1.35) { _, now in if now { crowned = true } }
    }

    var body: some View {
        let winner = session.player(playerID)?.player ?? Player(name: "?", colorIndex: 0)
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            ZStack {
                Q.yellow.ignoresSafeArea()
                Confetti(t: t).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Wabbel hält die Krone hoch und wirft sie dem Sieger auf den Kopf.
                    ZStack {
                        PlayerAvatar(player: winner, size: 120)
                        WabbelView(mood: t < 1.35 ? .present : .cheer, size: 90)
                            .offset(x: 118, y: 34)
                        crown(t)
                    }
                    .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0, 0.45))))
                    .padding(.top, 70)

                    Text(winner.name)
                        .font(.q(56))
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .foregroundStyle(Q.ink)
                        .padding(.top, 14)
                        .opacity(Ease.segment(t, 0.2, 0.45))
                    StickerLabel(text: "ist nicht der Dümmste!", fill: Q.blue, size: 24, tilt: -3)
                        .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0.35, 0.7))))

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(session.engine.ranking.enumerated()), id: \.element.id) { i, state in
                                HStack(spacing: 12) {
                                    Text("\(i + 1).")
                                        .font(.q(20))
                                        .foregroundStyle(Q.muted)
                                        .frame(width: 34, alignment: .trailing)
                                    PlayerAvatar(player: state.player, size: 36)
                                    Text(state.player.name).font(.qBody(18, .heavy)).foregroundStyle(Q.ink).lineLimit(1)
                                    Spacer()
                                    Text("\(state.totalCorrect)/\(state.totalCorrect + state.totalWrong) richtig")
                                        .font(.qBody(14, .bold))
                                        .foregroundStyle(Q.muted)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .card(radius: 20)
                                .opacity(Ease.segment(t, 0.7 + Double(i) * 0.08, 0.95 + Double(i) * 0.08))
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 4)
                    }

                    if session.engine.history.contains(where: { !$0.outcome.isCorrect }) {
                        Button { showDumbest = true } label: {
                            Label("Dümmste Antwort des Abends", systemImage: "star.fill")
                        }
                        .buttonStyle(QButtonStyle(fill: Q.pink, height: 54, fontSize: 18))
                        .padding(.bottom, 10)
                    }
                    HStack(spacing: 12) {
                        Button("Zum Start") { model.endGame() }
                            .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, fontSize: 20))
                        Button("Nochmal") { model.restartWithSamePlayers() }
                            .buttonStyle(QButtonStyle(fontSize: 22))
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
        }
        .sensoryFeedback(.success, trigger: start)
        .sensoryFeedback(.impact(weight: .heavy), trigger: crowned) { _, new in new }
        .sheet(isPresented: $showDumbest) { DumbestAnswerSheet(session: session) }
        .onAppear {
            start = Date()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-showDumbest") { showDumbest = true }
            #endif
        }
    }
}

/// Duell-Leiste im Finale: beide Finalisten mit ihren Herzen, wer dran ist, leuchtet.
struct DuelBar: View {
    let session: GameSession

    var body: some View {
        let finalists = session.engine.activePlayers
        let currentID = session.engine.currentPlayer.id
        if finalists.count == 2 {
            HStack(spacing: 8) {
                side(finalists[0], active: finalists[0].id == currentID, leading: true)
                Text("VS")
                    .font(.q(15))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Q.ink))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .zIndex(1)
                side(finalists[1], active: finalists[1].id == currentID, leading: false)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentID)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(finalists.map { "\($0.player.name) \($0.lives) Leben" }.joined(separator: ", "))
        }
    }

    private func side(_ state: PlayerState, active: Bool, leading: Bool) -> some View {
        let avatar = PlayerAvatar(player: state.player, size: 34)
        let hearts = HeartsRow(lives: state.lives, maxLives: session.settings.finaleLives, size: 15, fill: Q.red, empty: Q.ink.opacity(0.12))
        return HStack(spacing: 6) {
            if leading { avatar; hearts } else { hearts; avatar }
        }
        .padding(5)
        .padding(leading ? .trailing : .leading, 6)
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .background(Capsule().fill(.white))
        .overlay(Capsule().strokeBorder(Q.playerColor(state.player.colorIndex), lineWidth: active ? 3 : 0))
        .shadow(color: .black.opacity(active ? 0.14 : 0.05), radius: 8, y: 3)
        .scaleEffect(active ? 1 : 0.92)
        .opacity(active ? 1 : 0.7)
    }
}
