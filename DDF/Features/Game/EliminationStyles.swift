import SwiftUI

/// Wie jemand rausfliegt. Jeder Rauswurf bekommt eine andere Animation:
/// Gezogen wird wie aus einem Beutel, erst wenn alle dran waren, geht es von vorne los,
/// und nie zweimal dieselbe hintereinander.
enum EliminationStyle: String, CaseIterable {
    case kick, rocket, catapult, trapdoor, swallow

    @MainActor private static var bag: [EliminationStyle] = []
    @MainActor private static var last: EliminationStyle?

    @MainActor static func next() -> EliminationStyle {
        #if DEBUG
        // Zum Testen einer bestimmten Variante: `-elimStyle rocket` usw.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-elimStyle"), i + 1 < args.count, let forced = EliminationStyle(rawValue: args[i + 1]) {
            return forced
        }
        #endif
        if bag.isEmpty {
            bag = allCases.shuffled()
            if bag.first == last, bag.count > 1 { bag.swapAt(0, 1) }
        }
        let style = bag.removeFirst()
        last = style
        return style
    }
}

// MARK: - Rakete

/// Unter dem Sticker zündet ein Antrieb, er zittert und schießt mit Rauchspur nach oben weg.
struct RocketExit: View {
    let t: Double
    let player: Player

    private static func lift(_ t: Double) -> Double { -1400 * Ease.inCubic(Ease.segment(t, 1.0, 1.6)) }

    var body: some View {
        let appear = Ease.outBack(Ease.segment(t, 0, 0.35))
        let ignition = Ease.segment(t, 0.35, 0.7)
        let shake = t > 0.35 && t < 1.05 ? sin(t * 70) * 4 * ignition : 0
        let y = Self.lift(t)

        ZStack {
            // Rauchwolken bleiben dort stehen, wo die Rakete war.
            ForEach(0..<16, id: \.self) { i in
                let born = 0.95 + Double(i) * 0.04
                let age = t - born
                if age > 0, age < 1.0 {
                    Circle()
                        .fill(.white.opacity(0.75 * (1 - age)))
                        .frame(width: 30 + 70 * age, height: 30 + 70 * age)
                        .offset(x: sin(Double(i) * 2.3) * 18 * (1 + age), y: Self.lift(born) + 70 + 30 * age)
                }
            }

            // Flamme
            if ignition > 0, t < 1.7 {
                let flicker = 0.75 + 0.25 * sin(t * 47) * sin(t * 31)
                VStack(spacing: -18) {
                    Capsule().fill(Q.yellow).frame(width: 34, height: 70 * flicker * ignition)
                    Capsule().fill(Q.orange.opacity(0.8)).frame(width: 22, height: 50 * flicker * ignition)
                }
                .frame(height: 120, alignment: .top)
                .offset(x: shake, y: y + 110)
            }

            PlayerCard(player: player)
                .scaleEffect(max(0.01, appear))
                .rotationEffect(.degrees(-2 + shake * 0.4))
                .offset(x: shake, y: y)

            WabbelView(mood: t < 0.35 ? .idle : (t < 1.0 ? .shock : .present), size: 110)
                .offset(x: -110, y: 190)
        }
    }
}

// MARK: - Katapult

/// Wabbel lädt den Sticker auf den Kopf, staucht sich zusammen wie eine Feder und schleudert ihn weg.
struct CatapultExit: View {
    let t: Double
    let player: Player

    var body: some View {
        let appear = Ease.outBack(Ease.segment(t, 0, 0.3))
        let load = Ease.inOutCubic(Ease.segment(t, 0.3, 0.6))
        let charge = Ease.inCubic(Ease.segment(t, 0.55, 1.0))
        let fly = Ease.outCubic(Ease.segment(t, 1.0, 1.6))
        let spring = Ease.wobble(Ease.segment(t, 1.0, 2.2), frequency: 3, decay: 3.5)
        let tremble = t > 0.7 && t < 1.0 ? sin(t * 90) * 2 * charge : 0
        let wabbelY = 210.0

        // Wabbel als Feder: erst gestaucht, beim Loslassen lang gezogen und nachwippend.
        let sy = t < 1.0 ? 1 - 0.38 * charge : 1 + 0.35 * spring
        let sx = t < 1.0 ? 1 + 0.25 * charge : 1 - 0.2 * spring
        let headY = wabbelY - 60 - 80 * (sy - 1) * 0.9

        ZStack {
            WabbelView(mood: t < 1.0 ? .nervous : .present, size: 140)
                .scaleEffect(x: sx, y: sy, anchor: .bottom)
                .offset(x: tremble, y: wabbelY)

            PlayerCard(player: player)
                .scaleEffect(max(0.01, appear) * (1 - 0.35 * load))
                .rotationEffect(.degrees(-2 + 720 * fly))
                .offset(x: tremble + 520 * fly,
                        y: (headY - 60) * load + (t >= 1.0 ? -900 * fly + 400 * fly * fly : 0))
        }
    }
}

// MARK: - Falltür

/// Unter dem Sticker geht eine Klappe auf, er fällt hinein. Wabbel zieht am Hebel.
struct TrapdoorExit: View {
    let t: Double
    let player: Player

    var body: some View {
        let appear = Ease.outBack(Ease.segment(t, 0, 0.35))
        let open = Ease.outBack(Ease.segment(t, 0.6, 0.85)) * (1 - Ease.inCubic(Ease.segment(t, 1.45, 1.7)))
        let fall = Ease.inCubic(Ease.segment(t, 0.85, 1.25))
        let wobble = t > 0.6 && t < 0.85 ? sin(t * 60) * 3 : 0
        let lever = Ease.outBack(Ease.segment(t, 0.45, 0.65), overshoot: 3)

        ZStack {
            // Loch im Boden
            ZStack {
                Ellipse().fill(Q.ink)
                Ellipse().strokeBorder(.white.opacity(0.9), lineWidth: 5)
            }
            .frame(width: 300 * max(0, open), height: 90 * max(0, open))
            .offset(y: 70)

            PlayerCard(player: player)
                .scaleEffect(max(0.01, appear) * (1 - 0.8 * fall), anchor: .bottom)
                .rotation3DEffect(.degrees(50 * fall), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
                .rotationEffect(.degrees(-2 + wobble))
                .offset(y: 70 * fall)
                .opacity(t < 1.25 ? 1 : 0)
                // Unterhalb der Lochmitte verschwindet der Sticker im Loch.
                .mask(alignment: .top) { Rectangle().frame(height: 520).offset(y: -410 + 70 + 45 * open) }

            // Hebel mit Wabbel
            ZStack(alignment: .bottom) {
                Capsule().fill(Q.ink).frame(width: 46, height: 14)
                Capsule().fill(.white).frame(width: 10, height: 70)
                    .overlay(alignment: .top) { Circle().fill(Q.red).frame(width: 22, height: 22).offset(y: -8) }
                    .rotationEffect(.degrees(-35 + 70 * lever), anchor: .bottom)
                    .offset(y: -6)
            }
            .offset(x: 70, y: 250)
            WabbelView(mood: t < 0.45 ? .idle : (t < 1.3 ? .smug : .laugh), size: 110)
                .offset(x: 140, y: 225)
        }
    }
}

// MARK: - Verschlucken

/// Wabbel reißt den Mund auf, schlürft den Sticker ein, kaut und spuckt eine Papierkugel aus.
struct SwallowExit: View {
    let t: Double
    let player: Player

    var body: some View {
        let appear = Ease.outBack(Ease.segment(t, 0, 0.35))
        let slurp = Ease.inCubic(Ease.segment(t, 0.95, 1.3))
        let chewing = t > 1.3 && t < 2.1 ? sin((t - 1.3) * 2 * .pi * 4) : 0
        let full = Ease.outBack(Ease.segment(t, 1.3, 1.45)) * (1 - Ease.segment(t, 1.95, 2.15))
        let spit = Ease.segment(t, 2.05, 2.7)
        let wabbelY = 200.0
        let size = 170.0
        let mouthY = wabbelY + size * 0.915 * 0.053

        ZStack {
            WabbelView(mood: t < 0.6 ? .idle : (t < 1.3 ? .shock : (t < 2.05 ? .smug : .laugh)), size: size)
                .scaleEffect(x: 1 + 0.18 * full + 0.04 * chewing, y: 1 - 0.05 * full - 0.06 * chewing, anchor: .bottom)
                .offset(y: wabbelY)

            PlayerCard(player: player)
                .scaleEffect(max(0.01, appear) * (1 - 0.95 * slurp))
                .rotationEffect(.degrees(-2 + 260 * slurp))
                .offset(y: mouthY * slurp)
                .opacity(t < 1.3 ? 1 : 0)

            // Ausgespuckte Papierkugel
            if spit > 0, spit < 1 {
                Circle()
                    .fill(Q.playerColor(player.colorIndex))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .frame(width: 26, height: 26)
                    .offset(x: 170 * spit, y: mouthY - 140 * sin(spit * .pi) + 120 * spit)
            }
        }
    }
}
