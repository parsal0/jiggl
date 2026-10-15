import SwiftUI

/// Rauswurf: Der Sticker des Spielers wird abgezogen und fliegt aus dem Bild, dann kommt „Fliegt!“.
struct EliminationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: GameSession
    let playerID: UUID
    @State private var start = Date()
    @State private var peeled = false
    @State private var slammed = false
    /// Bei jedem Rauswurf eine andere Animation.
    @State private var style = EliminationStyle.kick

    var body: some View {
        let player = session.player(playerID)?.player ?? Player(name: "?", colorIndex: 0)

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            // Kein Blitzen bei „Bewegung reduzieren“.
            let flash = !reduceMotion && (t > 1.0 && t < 1.08 || t > 1.14 && t < 1.22)
            ZStack {
                (flash ? Q.red : Q.pink).ignoresSafeArea()

                VStack(spacing: 14) {
                    StickerLabel(text: "Tschüss, \(player.name)!", fill: .white, foreground: Q.pink, size: 26, tilt: -4)
                        .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0.1, 0.45))))
                    StickerLabel(text: "Raus", fill: Q.ink, size: 22, tilt: 3)
                        .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0.25, 0.6))))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 80)
                .padding(.horizontal, 30)

                switch style {
                case .kick:
                    speedLines(t)

                    PlayerCard(player: player)
                        .modifier(PeelEffect(t: t))

                    // Wabbel hüpft rein, tritt den Sticker aus dem Bild und winkt hinterher.
                    WabbelView(mood: wabbelMood(t), size: 110)
                        .offset(x: -96 - 420 * (1 - Ease.outCubic(Ease.segment(t, 0.05, 0.45))),
                                y: 96 + 80 * Ease.inOutCubic(Ease.segment(t, 1.25, 1.6))
                                    - 40 * sin(Ease.segment(t, 0.05, 0.45) * .pi))
                case .rocket: RocketExit(t: t, player: player)
                case .catapult: CatapultExit(t: t, player: player)
                case .trapdoor: TrapdoorExit(t: t, player: player)
                case .swallow: SwallowExit(t: t, player: player)
                }

                VStack(spacing: 4) {
                    Text("Fliegt!")
                        .font(.q(110))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .foregroundStyle(.white)
                        .scaleEffect(x: 1, y: stretch(t, delay: 0), anchor: .bottom)
                    Text("\(player.name) ist raus")
                        .font(.q(28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white.opacity(0.85))
                        .scaleEffect(x: 1, y: stretch(t, delay: 0.12), anchor: .bottom)
                }
                .padding(.horizontal, 16)

                footer
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(Ease.segment(t, 1.9, 2.2))
                    .offset(y: 40 * (1 - Ease.outBack(Ease.segment(t, 1.9, 2.3))))
                    .allowsHitTesting(t > 1.9)
            }
            .onChange(of: t > 1.0) { _, v in if v { peeled = true } }
            .onChange(of: t > 1.5) { _, v in if v { slammed = true } }
        }
        .contentShape(Rectangle())
        // Tipp irgendwo auf den Screen wirkt wie „Weiter“, sobald „Fliegt!“ eingeschlagen ist.
        .onTapGesture { if slammed { session.continueAfterElimination() } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: peeled)
        .sensoryFeedback(.error, trigger: slammed)
        .onAppear {
            // Hier ziehen statt beim Anlegen des States: SwiftUI legt Views öfter neu an.
            style = EliminationStyle.next()
            start = Date()
        }
    }

    /// Tritt so, dass der Fuß genau beim Abziehen des Stickers trifft.
    private func wabbelMood(_ t: Double) -> WabbelView.Mood {
        let kickStart = 1.0 - WabbelView.kickImpact
        if t < kickStart { return .idle }
        return t < 1.8 ? .kick : .wave
    }

    private func stretch(_ t: Double, delay: Double) -> CGFloat {
        let x = Ease.segment(t, 1.45 + delay, 1.8 + delay)
        return CGFloat(max(0, Ease.outBack(x, overshoot: 2.4)))
    }

    private func speedLines(_ t: Double) -> some View {
        let k = Ease.segment(t, 1.0, 1.4)
        let fade = 1 - Ease.segment(t, 1.4, 1.7)
        return VStack(alignment: .leading, spacing: 28) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(.white.opacity(0.45))
                    .frame(width: [160, 220, 120][i] * CGFloat(Ease.outCubic(k)), height: 8)
                    .offset(x: [40, 20, 60][i] + 200 * CGFloat(Ease.segment(t, 1.4, 1.7)))
            }
        }
        .opacity(k > 0 ? fade : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: -20)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(spacing: -2) {
                Text("\(session.engine.activePlayers.count)").font(.q(26))
                Text("übrig").font(.qBody(12, .bold)).foregroundStyle(Q.muted)
            }
            .foregroundStyle(Q.ink)
            .frame(width: 84, height: 64)
            .card(radius: 22)

            Button("Weiter") { session.continueAfterElimination() }
                .buttonStyle(QButtonStyle(fill: .white, foreground: Q.ink, height: 64, fontSize: 24))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

/// Großer Spieler-Sticker in der Spielerfarbe.
struct PlayerCard: View {
    var player: Player
    var subtitle = "0 Leben übrig"

    var body: some View {
        let fg = Q.onPlayerColor(player.colorIndex)
        HStack(spacing: 14) {
            Text(player.initial)
                .font(.q(36))
                .foregroundStyle(Q.playerColor(player.colorIndex))
                .frame(width: 72, height: 72)
                .background(Circle().fill(.white))
            VStack(alignment: .leading, spacing: 0) {
                Text(player.name).font(.q(48)).lineLimit(1).minimumScaleFactor(0.5)
                Text(subtitle).font(.qBody(14, .bold)).opacity(0.85)
            }
            .foregroundStyle(fg)
        }
        .padding(.leading, 14).padding(.trailing, 28).padding(.vertical, 14)
        .sticker(Q.playerColor(player.colorIndex), radius: 60, border: 6)
        .padding(.horizontal, 30)
    }
}

/// Auftauchen, Zittern, Abziehen, Wegfliegen.
struct PeelEffect: ViewModifier {
    var t: Double

    func body(content: Content) -> some View {
        let appear = Ease.outBack(Ease.segment(t, 0, 0.35))
        let jitter = t > 0.55 && t < 1.0 ? sin(t * 60) * 3 : 0
        let peel = Ease.segment(t, 0.85, 1.0)
        let fly = Ease.inCubic(Ease.segment(t, 1.0, 1.55))
        content
            .scaleEffect(max(0.01, appear) * (1 + 0.04 * peel) * (1 - 0.4 * fly))
            .rotation3DEffect(.degrees(-28 * peel), axis: (x: 0.2, y: 1, z: 0), anchor: .leading, perspective: 0.6)
            .rotationEffect(.degrees(-2 + jitter - 6 * peel + 44 * fly))
            .offset(x: 440 * fly, y: -680 * fly)
            .opacity(t > 1.55 ? 0 : 1)
    }
}
