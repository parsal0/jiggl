import SwiftUI

/// Der Schriftzug „Jiggl“ als Sticker: pinke Buchstaben mit weißem Rand.
/// Der i-Punkt ist ein kleiner Wackelpudding-Würfel wie Wabbel. Die Buchstaben wabbeln leicht vor sich hin,
/// beim Antippen schwappt eine Welle durch das Wort.
struct JigglLogo: View {
    var size: CGFloat = 48
    var fill: Color = Q.brand
    var outline: Color = .white
    /// Buchstaben ploppen nacheinander herein, z. B. auf dem Startbildschirm.
    var popIn = false
    /// Wartezeit vor dem Hereinploppen in Sekunden.
    var popDelay: Double = 0
    /// Aus für Standbilder, z. B. beim Teilen als Bild.
    var animated = true

    @State private var start = Date()
    @State private var poke = Date.distantPast

    /// „ı“ ohne Punkt, der Punkt wird als Würfel gezeichnet.
    private static let letters: [String] = ["J", "ı", "g", "g", "l"]
    private static let dotIndex = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !animated)) { context in
            let t = animated ? context.date.timeIntervalSince(start) - (popIn ? popDelay : 0) : 10
            let sincePoke = animated ? context.date.timeIntervalSince(poke) : 10
            HStack(alignment: .firstTextBaseline, spacing: -size * 0.03) {
                ForEach(Self.letters.indices, id: \.self) { i in
                    letter(i, t: t, sincePoke: sincePoke)
                }
            }
        }
        .padding(.top, size * 0.12)
        .contentShape(Rectangle())
        .onTapGesture { if animated { poke = Date() } }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: poke)
        .onAppear { start = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Jiggl")
        .accessibilityAddTraits(.isHeader)
    }

    private func letter(_ i: Int, t: Double, sincePoke: Double) -> some View {
        let jelly = squash(i, t: t, sincePoke: sincePoke)
        let pop = popIn ? Ease.outBack(Ease.segment(t, 0.08 * Double(i), 0.08 * Double(i) + 0.35), overshoot: 2.4) : 1
        return glyph(Self.letters[i])
            .overlay(alignment: .top) {
                if i == Self.dotIndex { dot(t: t, sincePoke: sincePoke) }
            }
            .scaleEffect(x: jelly.sx, y: jelly.sy, anchor: .bottom)
            .rotationEffect(.degrees(tilt(i)), anchor: .bottom)
            .scaleEffect(max(0.01, pop), anchor: .bottom)
            .opacity(popIn ? min(1, pop * 4) : 1)
    }

    /// Buchstabe mit dickem Rand und weichem Schatten, wie ein ausgeschnittener Sticker.
    private func glyph(_ text: String) -> some View {
        let font = Font.system(size: size, weight: .black, design: .rounded)
        let border = max(2, size * 0.075)
        return Text(text)
            .font(font)
            .foregroundStyle(fill)
            .background {
                ZStack {
                    ForEach(0..<16, id: \.self) { k in
                        let a = Double(k) / 16 * 2 * .pi
                        Text(text).font(font).foregroundStyle(outline)
                            .offset(x: cos(a) * border, y: sin(a) * border)
                    }
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.14), radius: size * 0.08, y: size * 0.05)
            }
    }

    /// Der i-Punkt: ein runder Würfel mit Glanz, der ab und zu hüpft.
    private func dot(t: Double, sincePoke: Double) -> some View {
        let d = size * 0.3
        // Alle 3,2 Sekunden ein kleiner Hüpfer, beim Antippen ein großer.
        let cycle = t.truncatingRemainder(dividingBy: 3.2)
        let hop = sin(Ease.segment(cycle, 1.6, 2.0) * .pi) * 0.35 + sin(Ease.segment(sincePoke, 0.1, 0.55) * .pi) * 0.9
        let land = Ease.wobble(Ease.segment(cycle, 2.0, 2.6), frequency: 2.5, decay: 5)
            + Ease.wobble(Ease.segment(sincePoke, 0.55, 1.2), frequency: 2.5, decay: 5) * 1.6
        let pop = popIn ? Ease.outBack(Ease.segment(t, 0.55, 0.9), overshoot: 2.6) : 1
        let shape = RoundedRectangle(cornerRadius: d * 0.34, style: .continuous)
        return shape
            .fill(fill)
            .overlay(alignment: .topLeading) {
                Capsule().fill(.white.opacity(0.75))
                    .frame(width: d * 0.38, height: d * 0.16)
                    .rotationEffect(.degrees(-25))
                    .offset(x: d * 0.14, y: d * 0.18)
            }
            .frame(width: d, height: d)
            .padding(max(2, size * 0.055))
            .background(RoundedRectangle(cornerRadius: d * 0.48, style: .continuous).fill(outline))
            .shadow(color: .black.opacity(0.14), radius: size * 0.06, y: size * 0.04)
            .scaleEffect(x: 1 + 0.2 * land, y: 1 - 0.2 * land, anchor: .bottom)
            .rotationEffect(.degrees(8))
            .offset(y: -size * 0.07 - hop * size * 0.35)
            .scaleEffect(max(0.01, pop), anchor: .bottom)
    }

    /// Leichtes Wabbeln je Buchstabe, versetzt, damit eine Welle durchläuft. Antippen verstärkt es kurz.
    private func squash(_ i: Int, t: Double, sincePoke: Double) -> (sx: Double, sy: Double) {
        let phase = Double(i) * 0.7
        let idle = sin(t * 2.4 - phase) * 0.025
        let wave = Ease.wobble(Ease.segment(sincePoke - Double(i) * 0.06, 0, 0.9), frequency: 2.5, decay: 4.5) * 0.18
        let landing = popIn ? Ease.wobble(Ease.segment(t, 0.08 * Double(i) + 0.3, 0.08 * Double(i) + 1.0), frequency: 2.5, decay: 4.5) * 0.15 : 0
        let s = idle + wave + landing
        return (1 + s * 0.8, 1 - s)
    }

    /// Jeder Buchstabe sitzt etwas schief, wie von Hand geklebt.
    private func tilt(_ i: Int) -> Double {
        [-5, 3, -2, 4, -3][i]
    }
}

/// Kleines Markenzeichen für Fußzeilen: Wabbel neben dem Schriftzug.
struct JigglBadge: View {
    var size: CGFloat = 22
    var fill: Color = Q.brand
    var animated = true

    var body: some View {
        HStack(alignment: .center, spacing: size * 0.1) {
            WabbelView(mood: .idle, size: size * 1.7, animated: animated)
                .allowsHitTesting(false)
            JigglLogo(size: size, fill: fill, animated: animated)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        JigglLogo(size: 80, popIn: true)
        JigglLogo(size: 40)
        JigglBadge()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Q.blue)
}
