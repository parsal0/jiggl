import SwiftUI

/// Ein Herz taucht auf, zittert und bricht in zwei Hälften, die herunterfallen. Dazu „−1“.
struct HeartBreak: View {
    var size: CGFloat = 54
    var delay: Double = 0
    @State private var start = Date()
    @State private var broken = false

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start) - delay
            let appear = Ease.outBack(Ease.segment(t, 0, 0.25), overshoot: 2.2)
            let shake = t > 0.3 && t < 0.55 ? sin(t * 80) * 3 : 0
            let split = Ease.inCubic(Ease.segment(t, 0.55, 1.2))
            let fade = 1 - Ease.segment(t, 1.0, 1.25)
            ZStack {
                half(left: true)
                    .rotationEffect(.degrees(-28 * split), anchor: .bottom)
                    .offset(x: shake - 22 * split, y: 80 * split * split)
                half(left: false)
                    .rotationEffect(.degrees(28 * split), anchor: .bottom)
                    .offset(x: shake + 22 * split, y: 80 * split * split)
                Text("−1")
                    .font(.q(size * 0.55))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .scaleEffect(max(0.01, Ease.outBack(Ease.segment(t, 0.55, 0.8), overshoot: 2.5)))
                    .offset(x: size * 0.95, y: -size * 0.15)
            }
            .opacity(t < 0 ? 0 : fade)
            .scaleEffect(max(0.01, appear))
            .onChange(of: t > 0.55) { _, now in if now { broken = true } }
        }
        .frame(width: size * 2.4, height: size * 1.3)
        .sensoryFeedback(.impact(weight: .medium), trigger: broken) { _, new in new }
        .onAppear { start = Date() }
        .accessibilityLabel("Ein Leben verloren")
    }

    private func half(left: Bool) -> some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Q.red)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 3)
            .overlay(Image(systemName: "heart").font(.system(size: size, weight: .heavy)).foregroundStyle(.white))
            .mask(CrackHalf(left: left))
    }
}

/// Linke oder rechte Hälfte, getrennt durch einen Zickzack-Riss.
private struct CrackHalf: Shape {
    var left: Bool

    func path(in rect: CGRect) -> Path {
        let zig: [(CGFloat, CGFloat)] = [(0.5, 0), (0.42, 0.25), (0.58, 0.45), (0.44, 0.65), (0.55, 0.82), (0.5, 1)]
        var path = Path()
        path.move(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.minY))
        for (x, y) in zig { path.addLine(to: CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)) }
        path.addLine(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Weicher Lichtkegel von oben, z. B. für das Finale.
struct Spotlight: View {
    var body: some View {
        Canvas { ctx, size in
            var cone = Path()
            cone.move(to: CGPoint(x: size.width / 2 - 30, y: 0))
            cone.addLine(to: CGPoint(x: size.width / 2 + 30, y: 0))
            cone.addLine(to: CGPoint(x: size.width, y: size.height))
            cone.addLine(to: CGPoint(x: 0, y: size.height))
            cone.closeSubpath()
            ctx.fill(cone, with: .linearGradient(Gradient(colors: [.white.opacity(0.05), .white.opacity(0.28)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            ctx.fill(Path(ellipseIn: CGRect(x: 0, y: size.height - 30, width: size.width, height: 60)),
                     with: .color(.white.opacity(0.28)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
