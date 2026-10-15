import SwiftUI

// MARK: - Flächen

extension View {
    /// Bunter Sticker: Vollfarbe, weißer Rand, weicher Schatten.
    func sticker(_ fill: Color, radius: CGFloat = Q.radius, border: CGFloat = Q.border) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(fill))
            .overlay(shape.strokeBorder(.white, lineWidth: border))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    /// Weiße Karte mit weichem Schatten.
    func card(radius: CGFloat = Q.radius) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Q.surface))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }
}

/// Kurzer Text als schräg geklebter Sticker, z. B. „Richtig!“ oder „Finale!“.
struct StickerLabel: View {
    var text: String
    var fill: Color
    var foreground: Color = .white
    var size: CGFloat = 28
    var tilt: Double = -4

    var body: some View {
        Text(text)
            .font(.q(size))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, size * 0.5)
            .padding(.vertical, size * 0.22)
            .sticker(fill, radius: size * 0.55, border: max(3, size * 0.1))
            .rotationEffect(.degrees(tilt))
    }
}

// MARK: - Knöpfe

/// Großer Knopf in Pillenform. Standard: schwarz mit weißer Schrift.
struct QButtonStyle: ButtonStyle {
    var fill: Color = Q.ink
    var foreground: Color = .white
    var height: CGFloat = 62
    var fontSize: CGFloat = 22
    var radius: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius ?? height / 2, style: .continuous)
        configuration.label
            .font(.q(fontSize))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(shape.fill(fill))
            .shadow(color: .black.opacity(fill == Q.surface ? 0.08 : 0.14), radius: 10, y: 5)
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, new in new }
    }
}

/// Runder Icon-Knopf, weiß mit Schatten.
struct QIconButtonStyle: ButtonStyle {
    var size: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(Q.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Q.surface))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new }
    }
}

/// Auswahl-Pille, z. B. in den Regeln.
struct QPillStyle: ButtonStyle {
    var selected: Bool
    var tint: Color = Q.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.qBody(17, .heavy))
            .foregroundStyle(selected ? .white : Q.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 46)
            .background(Capsule().fill(selected ? tint : Q.surface))
            .overlay(Capsule().strokeBorder(selected ? .white : Q.line, lineWidth: selected ? 3 : 1.5))
            .shadow(color: .black.opacity(selected ? 0.14 : 0.04), radius: selected ? 8 : 4, y: selected ? 4 : 2)
            .rotationEffect(.degrees(selected ? -2 : 0))
            .scaleEffect(configuration.isPressed ? 0.94 : (selected ? 1.04 : 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: selected)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Spieler

/// Runder Spieler-Sticker mit Initiale.
struct PlayerAvatar: View {
    var player: Player
    var size: CGFloat = 40
    /// Weiß mit farbiger Initiale, für Hintergründe in der Spielerfarbe.
    var inverted = false

    var body: some View {
        let color = Q.playerColor(player.colorIndex)
        Text(player.initial)
            .font(.q(size * 0.48))
            .foregroundStyle(inverted ? color : Q.onPlayerColor(player.colorIndex))
            .frame(width: size, height: size)
            .background(Circle().fill(inverted ? .white : color))
            .overlay(Circle().strokeBorder(.white, lineWidth: max(2.5, size * 0.07)))
            .shadow(color: .black.opacity(0.14), radius: size * 0.15, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

/// Spieler als weiße Pille mit Avatar und Name.
struct PlayerChip: View {
    var player: Player
    var size: CGFloat = 18
    var tilt: Double = 0
    var dimmed = false
    var highlighted = false

    var body: some View {
        HStack(spacing: size * 0.5) {
            PlayerAvatar(player: player, size: size * 1.9)
            Text(player.name)
                .font(.qBody(size, .heavy))
                .foregroundStyle(Q.ink)
                .lineLimit(1)
            if let h = Handicap(rawValue: player.handicap), h != .normal {
                Image(systemName: h.symbol)
                    .font(.system(size: size * 0.75, weight: .bold))
                    .foregroundStyle(h.color)
                    .padding(.leading, -size * 0.2)
            }
        }
        .padding(.leading, size * 0.25)
        .padding(.trailing, size * 0.85)
        .padding(.vertical, size * 0.25)
        .background(Capsule().fill(Q.surface))
        .overlay(Capsule().strokeBorder(highlighted ? Q.playerColor(player.colorIndex) : .clear, lineWidth: 3))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .rotationEffect(.degrees(tilt))
        .opacity(dimmed ? 0.4 : 1)
        .saturation(dimmed ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(player.name)
    }
}

/// Wiederholbare, leicht unterschiedliche Neigung pro Index, wie von Hand geklebt.
func stickerTilt(_ index: Int) -> Double {
    [-3, 2, -1, 3, -2, 1, -2.5, 2.5][((index % 8) + 8) % 8]
}

// MARK: - Spielanzeigen

/// Reihe von Herzen. Verlorene Leben sind blass.
struct HeartsRow: View {
    var lives: Int
    var maxLives: Int
    var size: CGFloat = 22
    var fill: Color = .white
    var empty: Color = .white.opacity(0.3)

    /// Ab so vielen Leben zeigt die Reihe ein Herz mit Zahl statt einzelner Herzen.
    static let compactThreshold = 6

    var body: some View {
        if max(maxLives, lives) > Self.compactThreshold { compact } else { row }
    }

    private var compact: some View {
        HStack(spacing: size * 0.25) {
            Image(systemName: "heart.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(lives > 0 ? fill : empty)
            Text("\(lives)")
                .font(.q(size * 0.95))
                .monospacedDigit()
                .foregroundStyle(fill)
                .contentTransition(.numericText(value: Double(lives)))
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: lives)
        }
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .accessibilityElement()
        .accessibilityLabel("\(lives) von \(maxLives) Leben")
    }

    private var row: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0..<max(maxLives, lives), id: \.self) { i in
                let alive = i < lives
                Image(systemName: "heart.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(alive ? fill : empty)
                    .shadow(color: alive ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
                    .scaleEffect(alive ? 1 : 0.82)
                    .animation(.spring(response: 0.35, dampingFraction: 0.45), value: alive)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(lives) von \(maxLives) Leben")
    }
}

/// Zeitbalken auf farbigem Grund: weiß, am Ende in der Warnfarbe.
struct TimerBar: View {
    var remainingFraction: Double

    var body: some View {
        let f = min(max(remainingFraction, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule()
                    .fill(f > 0.25 ? .white : Q.yellow)
                    .frame(width: max(geo.size.height, geo.size.width * f))
                    .opacity(f > 0 ? 1 : 0)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

/// Wackeln, z. B. in den letzten Sekunden.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// Fallende Konfetti-Formen in den bunten Farben.
struct Confetti: View {
    var t: Double

    private struct Piece {
        let x, delay, speed, spin, size: Double
        let kind: Int
        let color: Color
    }

    private static let pieces: [Piece] = {
        var rng = SplitMix64(seed: 42)
        let colors = [Q.blue, Q.pink, Q.orange, Q.green, Q.purple, Q.yellow, Q.sky]
        return (0..<50).map { _ in
            Piece(x: Double.random(in: 0...1, using: &rng),
                  delay: Double.random(in: 0...1.2, using: &rng),
                  speed: Double.random(in: 120...260, using: &rng),
                  spin: Double.random(in: -4...4, using: &rng),
                  size: Double.random(in: 10...20, using: &rng),
                  kind: Int.random(in: 0...1, using: &rng),
                  color: colors.randomElement(using: &rng)!)
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for p in Self.pieces {
                let local = t - p.delay
                guard local > 0 else { continue }
                let travel = size.height + 80
                let y = (local * p.speed).truncatingRemainder(dividingBy: travel) - 40
                let x = p.x * size.width + sin(local * 2 + p.x * 10) * 18
                var c = ctx
                c.translateBy(x: x, y: y)
                c.rotate(by: .radians(local * p.spin))
                let r = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.kind == 0 ? p.size * 0.45 : p.size)
                let path = p.kind == 0 ? Path(roundedRect: r, cornerRadius: 3) : Path(ellipseIn: r)
                c.fill(path, with: .color(p.color))
            }
        }
        .accessibilityHidden(true)
    }
}
