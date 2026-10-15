import SwiftUI

/// Das Maskottchen. Körper, Arme und Füße sind Bilder, das Gesicht wird gezeichnet.
/// Dadurch kann Wabbel blinzeln, herumgucken, jeden Ausdruck zeigen und auf Antippen reagieren.
struct WabbelView: View {
    enum Mood: Equatable, CaseIterable {
        /// Ruhiges Wabbeln, blinzelt und schaut sich um.
        case idle
        /// Wird grün, hüpft und reißt die Arme hoch.
        case cheer
        /// Kringelt sich vor Lachen.
        case laugh
        /// Erschrickt mit großen Augen.
        case shock
        /// Lässt alles hängen.
        case sad
        /// Halb geschlossene Augen, schiefes Grinsen.
        case smug
        /// Bläst sich auf und zerplatzt in Pudding-Stücke.
        case explode
        /// Reißt die Arme hoch: „Tadaa!“
        case present
        /// Trommelt aufgeregt, Blick nach oben.
        case drumroll
        /// Zittert, schwitzt, Blick huscht hin und her.
        case nervous
        /// Schläft mit „Zzz“.
        case sleep
        /// Holt aus und tritt nach rechts. Der Tritt trifft nach `kickImpact` Sekunden.
        case kick
        /// Winkt zum Abschied.
        case wave
        /// Richter mit erhobenem Hammer.
        case judge
        /// Haut den Hammer runter.
        case verdict
        /// Hält sich die Augen zu und linst ab und zu.
        case coverEyes
        /// Plumpst von oben ins Bild und schüttelt sich, z. B. beim App-Start.
        case land
        /// Zuckt mit den Schultern.
        case shrug
        /// Schmilzt zu einer Pfütze zusammen.
        case melt
        /// Verliert Luft wie ein Ballon, schwirrt herum und landet schlapp.
        case deflate
        /// Wird getroffen und torkelt mit Spiralaugen.
        case dizzy
        /// Hält ein Schild an zwei Stangen über den Kopf. Text kommt aus `sign`.
        case holdSign

        /// Wie viele Spielarten es gibt. Bei jedem Wechsel wird eine andere ausgesucht.
        var variants: Int {
            switch self {
            case .cheer: 4
            case .laugh, .shock, .sad, .present: 3
            case .smug, .drumroll, .nervous, .sleep, .wave, .judge, .coverEyes, .shrug: 2
            default: 1
            }
        }
    }

    /// Zeitpunkt, an dem der Fuß beim Treten trifft.
    static let kickImpact = 0.42

    var mood: Mood = .idle
    var size: CGFloat = 120
    /// Farbe eines Spielers (Index in `Q.playerColors`). Ohne Angabe bleibt Wabbel pink.
    var playerColor: Int? = nil
    /// Text auf dem Schild bei `.holdSign`, zum Beispiel der Name des Spielers.
    var sign: String? = nil
    var signColor: Color = Color(hex: 0x141414)
    /// Aus für Standbilder, z. B. beim Teilen als Bild.
    var animated = true

    @State private var start = Date()
    @State private var previous: Mood = .idle
    @State private var poke = Date.distantPast
    @State private var pokes: [Date] = []
    @State private var annoyed = Date.distantPast
    @State private var touch: CGPoint?
    @State private var touchTime = Date.distantPast
    @State private var popped = false
    @State private var seed = UInt64.random(in: 0...10_000)
    @State private var variant = 0
    @State private var previousVariant = 0
    @State private var pokeKind = PokeKind.wobble

    /// Zuletzt gezeigte Spielart je Stimmung, damit nicht zweimal hintereinander dasselbe kommt.
    private static var lastVariant: [Mood: Int] = [:]
    private static var lastPoke = PokeKind.wobble

    /// Ab hier ist Wabbel geplatzt.
    private static let popTime = 0.55
    /// Drehung des Farbtons von Pink nach Grün. Etwas gelblicher als das Grün von „Richtig!“, damit er sich abhebt.
    private static let greenHue = 118.0
    /// Ab hier ist Wabbel beim Plumpsen gelandet.
    private static let landTime = 0.32

    private var unit: CGFloat { size / Rig.canvas.width }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !animated)) { context in
            let now = context.date
            let t = animated ? now.timeIntervalSince(start) : 10
            let sincePoke = now.timeIntervalSince(poke)
            let m = motion(t: t, sincePoke: sincePoke)
            let cheer = mood == .cheer ? Ease.outCubic(Ease.segment(t, 0.05, 0.6)) : 0
            let tint = tint(cheer: cheer, glow: m.glow * (0.8 + 0.2 * sin(t * 2 * .pi * 9)))
            let expression = face(t: t, now: now)
            let fid = fidget(t: t, sincePoke: sincePoke)
            let knocks = fid?.kind == .knock ? Self.knockTimes.filter { fid!.local > $0 }.count : 0
            let u = unit

            ZStack {
                // Schatten bleibt am Boden und wird beim Springen kleiner.
                Ellipse()
                    .fill(.black.opacity(0.16 * m.opacity * max(0, 1 - 2.5 * m.dy)))
                    .frame(width: 620 * u * max(0.2, 1 - 1.5 * m.dy), height: 46 * u)
                    .position(x: (626 - Rig.origin.x) * u, y: (Rig.ground - Rig.origin.y) * u)

                ZStack {
                    part("WabbelFootLeft", Rig.footL, rotation: m.feet, pivot: .top, tint: tint)
                    part("WabbelFootRight", Rig.footR, rotation: -m.feet + m.kick, pivot: .top, tint: tint)

                    ZStack {
                        if !m.armsFront { arms(m, tint: tint) }
                        part("WabbelBody", Rig.body, tint: tint)
                        Canvas { ctx, _ in
                            ctx.scaleBy(x: u, y: u)
                            ctx.translateBy(x: -Rig.origin.x, y: -Rig.origin.y)
                            FacePainter(face: expression, ctx: ctx, time: now.timeIntervalSinceReferenceDate).draw()
                        }
                        if m.armsFront { arms(m, tint: tint) }
                        if mood == .holdSign, let sign { signBoard(sign, raised: m.signUp) }
                    }
                    .scaleEffect(x: m.sx, y: m.sy, anchor: Rig.bodyBottom)
                    .rotationEffect(.degrees(m.rotation), anchor: Rig.bodyBottom)
                }
                .scaleEffect(m.shrink, anchor: Rig.bodyBottom)
                .rotationEffect(.degrees(m.spin), anchor: Rig.bodyCenter)
                .offset(x: m.dx * size, y: -m.dy * size)
                .opacity(m.opacity)
            }
            // Beim Klopfen kommt er näher an die Scheibe.
            .scaleEffect(1 + m.closer, anchor: .bottom)
            .frame(width: size, height: size * Rig.canvas.height / Rig.canvas.width)
            .overlay(alignment: .topTrailing) {
                if mood == .sleep { snore(t: animated ? t : 1) }
            }
            .overlay {
                if mood == .explode {
                    let time = now.timeIntervalSinceReferenceDate
                    JellyExplosion(t: t - Self.popTime, size: size,
                                   blink: animated ? blink(time) : 0, look: animated ? glance(time) : .zero)
                        .frame(width: size * JellyExplosion.span, height: size * JellyExplosion.span)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: mood == .explode && t > Self.popTime) { _, now in if now { popped = true } }
            .sensoryFeedback(.impact(weight: .medium), trigger: knocks) { old, new in new > old }
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in tapped(at: location) }
        .onChange(of: mood) { old, new in
            previous = old
            previousVariant = variant
            variant = animated ? Self.pickVariant(for: new) : 0
            start = Date()
            popped = false
        }
        .onAppear {
            start = Date()
            previous = mood
            variant = animated ? Self.pickVariant(for: mood) : 0
            previousVariant = variant
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: poke)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: popped) { _, new in new }
        .accessibilityLabel("Wabbel")
    }

    // MARK: - Teile

    @ViewBuilder private func arms(_ m: Motion, tint: Tint) -> some View {
        let holdsSign = mood == .holdSign && sign != nil
        part("WabbelArmLeft", Rig.armL, rotation: m.armL, pivot: Rig.shoulderL, tint: tint,
             accessory: holdsSign ? { Self.pole($0, left: true, length: 310 * m.signUp) } : nil)
        let holdsGavel = mood == .judge || mood == .verdict
        part("WabbelArmRight", Rig.armR, rotation: m.armR, pivot: Rig.shoulderR, tint: tint,
             accessory: holdsGavel ? Self.gavel : (holdsSign ? { Self.pole($0, left: false, length: 310 * m.signUp) } : nil))
    }

    /// Holzstange in der Hand, in Koordinaten des Arm-Bildes. Zeigt bei erhobenem Arm (±150°) senkrecht nach oben.
    private static func pole(_ ctx: GraphicsContext, left: Bool, length: Double) {
        guard length > 1 else { return }
        let hand = CGPoint(x: left ? 78 : 128, y: 213)
        let dir = CGVector(dx: left ? -0.455 : 0.455, dy: 0.891)
        var stick = Path()
        stick.move(to: CGPoint(x: hand.x - dir.dx * 30, y: hand.y - dir.dy * 30))
        stick.addLine(to: CGPoint(x: hand.x + dir.dx * length, y: hand.y + dir.dy * length))
        ctx.stroke(stick, with: .color(Color(hex: 0x3A0614)), style: StrokeStyle(lineWidth: 40, lineCap: .round))
        ctx.stroke(stick, with: .color(Color(hex: 0xC98642)), style: StrokeStyle(lineWidth: 24, lineCap: .round))
    }

    /// Schild über dem Kopf, in Rig-Koordinaten. Die Stangen enden hinter der Unterkante.
    private func signBoard(_ text: String, raised: Double) -> some View {
        let u = unit
        let board = CGRect(x: 120, y: -250, width: 1000, height: 330)
        return Text(text)
            .font(.q(board.height * u * 0.6))
            .foregroundStyle(signColor)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, board.height * u * 0.25)
            .frame(width: board.width * u, height: board.height * u)
            .background(RoundedRectangle(cornerRadius: board.height * u * 0.22, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: board.height * u * 0.22, style: .continuous)
                .strokeBorder(Color(hex: 0x3A0614), lineWidth: max(2, 14 * u)))
            .scaleEffect(0.3 + 0.7 * raised, anchor: .bottom)
            .opacity(min(1, raised * 2))
            .position(x: (board.midX - Rig.origin.x) * u, y: (board.midY - Rig.origin.y) * u)
    }

    // MARK: - Farbe

    /// Farbe der Bild-Teile als Drehung gegenüber dem pinken Original. Das Gesicht bleibt, wie es ist.
    private struct Tint { var hue = 0.0, brightness = 0.0, saturation = 1.0 }

    /// Wabbel bleibt pink bzw. in der Spielerfarbe. Nur beim Jubeln wird er knallgrün, kurz vorm Platzen glüht er.
    private func tint(cheer: Double, glow: Double) -> Tint {
        let base = playerColor.map(Self.playerTint) ?? Tint()
        return Tint(hue: base.hue * (1 - cheer) + Self.greenHue * cheer,
                    brightness: base.brightness * (1 - cheer) + 0.16 * cheer + 0.12 * glow,
                    saturation: base.saturation * (1 - cheer) + (1.25) * cheer + 0.3 * glow)
    }

    /// Drehung vom pinken Original zur Spielerfarbe, in der Reihenfolge von `Q.playerColors`.
    private static let playerTints: [Tint] = [
        Tint(hue: 253, brightness: 0, saturation: 1.1),     // Blau
        Tint(),                                               // Pink
        Tint(hue: 48, brightness: 0.16, saturation: 1.25),   // Orange
        Tint(hue: 180, brightness: 0.1, saturation: 1.1),    // Grün
        Tint(hue: 280, brightness: 0, saturation: 1),        // Lila
        Tint(hue: 212, brightness: 0.16, saturation: 1.1),   // Hellblau
        Tint(hue: 22, brightness: 0.02, saturation: 1.1),    // Rot
        Tint(hue: 70, brightness: 0.32, saturation: 1.35),    // Gelb
    ]

    private static func playerTint(_ index: Int) -> Tint {
        let n = playerTints.count
        return playerTints[((index % n) + n) % n]
    }

    /// Richterhammer in der rechten Hand, in Koordinaten des Arm-Bildes.
    private static func gavel(_ ctx: GraphicsContext) {
        let hand = CGPoint(x: 128, y: 213)
        let dir = CGVector(dx: 0.454, dy: 0.891), perp = CGVector(dx: -0.891, dy: 0.454)
        let end = CGPoint(x: hand.x + dir.dx * 190, y: hand.y + dir.dy * 190)
        let ink = Color(hex: 0x3A0614)
        var handle = Path()
        handle.move(to: CGPoint(x: hand.x - dir.dx * 40, y: hand.y - dir.dy * 40))
        handle.addLine(to: end)
        ctx.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 46, lineCap: .round))
        ctx.stroke(handle, with: .color(Color(hex: 0xC98642)), style: StrokeStyle(lineWidth: 30, lineCap: .round))
        var head = Path()
        let hl = 95.0, hw = 48.0
        head.move(to: CGPoint(x: end.x - perp.dx * hl - dir.dx * hw, y: end.y - perp.dy * hl - dir.dy * hw))
        head.addLine(to: CGPoint(x: end.x + perp.dx * hl - dir.dx * hw, y: end.y + perp.dy * hl - dir.dy * hw))
        head.addLine(to: CGPoint(x: end.x + perp.dx * hl + dir.dx * hw, y: end.y + perp.dy * hl + dir.dy * hw))
        head.addLine(to: CGPoint(x: end.x - perp.dx * hl + dir.dx * hw, y: end.y - perp.dy * hl + dir.dy * hw))
        head.closeSubpath()
        ctx.fill(head, with: .linearGradient(Gradient(colors: [Color(hex: 0xD9A066), Color(hex: 0x8A5226)]),
                                             startPoint: CGPoint(x: end.x - dir.dx * hw, y: end.y - dir.dy * hw),
                                             endPoint: CGPoint(x: end.x + dir.dx * hw, y: end.y + dir.dy * hw)))
        ctx.stroke(head, with: .color(ink), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
        for k in [-0.6, 0.6] {
            var band = Path()
            band.move(to: CGPoint(x: end.x + perp.dx * hl * k - dir.dx * hw, y: end.y + perp.dy * hl * k - dir.dy * hw))
            band.addLine(to: CGPoint(x: end.x + perp.dx * hl * k + dir.dx * hw, y: end.y + perp.dy * hl * k + dir.dy * hw))
            ctx.stroke(band, with: .color(ink), lineWidth: 9)
        }
    }

    /// Aufsteigende „Z“ beim Schlafen.
    private func snore(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = (t * 0.45 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.q(size * (0.12 + 0.12 * phase)))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x3A0614).opacity(0.35), radius: 0, x: 1.5, y: 1.5)
                    .offset(x: size * (0.05 + 0.18 * phase) + size * 0.04 * sin(phase * 7),
                            y: -size * 0.55 * phase)
                    .opacity(sin(phase * .pi))
            }
        }
        .offset(x: -size * 0.12, y: size * 0.05)
        .allowsHitTesting(false)
    }

    private func part(_ name: String, _ rect: CGRect, rotation: Double = 0, pivot: UnitPoint = .center,
                      tint: Tint, accessory: ((GraphicsContext) -> Void)? = nil) -> some View {
        let u = unit
        return Image(name)
            .resizable()
            .hueRotation(.degrees(tint.hue))
            .brightness(tint.brightness)
            .saturation(tint.saturation)
            .frame(width: rect.width * u, height: rect.height * u)
            .overlay {
                if let accessory {
                    // Dreifach so groß, damit Zubehör über das Bild hinausragen darf.
                    Canvas { ctx, _ in
                        ctx.scaleBy(x: u, y: u)
                        ctx.translateBy(x: rect.width, y: rect.height)
                        accessory(ctx)
                    }
                    .frame(width: rect.width * u * 3, height: rect.height * u * 3)
                    .allowsHitTesting(false)
                }
            }
            .rotationEffect(.degrees(rotation), anchor: pivot)
            .position(x: (rect.midX - Rig.origin.x) * u, y: (rect.midY - Rig.origin.y) * u)
    }

    // MARK: - Antippen

    /// Wie Wabbel aufs Antippen reagiert. Kopf: Beule. Bauch und Füße: kitzelig. Sonst etwas Zufälliges.
    fileprivate enum PokeKind: CaseIterable {
        case wobble, bonk, tickle, hop, shy, spin

        var duration: Double {
            switch self {
            case .wobble: 1.2
            case .bonk: 1.0
            case .tickle: 1.6
            case .hop: 0.9
            case .shy: 2.0
            case .spin: 1.0
            }
        }
    }

    private static func pickVariant(for mood: Mood) -> Int {
        let n = mood.variants
        guard n > 1 else { return 0 }
        var v = Int.random(in: 0..<n)
        if v == lastVariant[mood] { v = (v + Int.random(in: 1..<n)) % n }
        lastVariant[mood] = v
        return v
    }

    private func tapped(at location: CGPoint) {
        let now = Date()
        let point = CGPoint(x: location.x / unit + Rig.origin.x, y: location.y / unit + Rig.origin.y)
        if point.y < Rig.browL.y + 90 {
            pokeKind = .bonk
        } else if point.y > Rig.mouth.y + 110 {
            pokeKind = .tickle
        } else {
            let pool: [PokeKind] = [.wobble, .hop, .shy, .spin].filter { $0 != Self.lastPoke }
            pokeKind = pool.randomElement() ?? .wobble
        }
        Self.lastPoke = pokeKind
        poke = now
        touch = point
        touchTime = now
        pokes = pokes.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        // Wer zu oft piekst, nervt.
        if pokes.count >= 4 { annoyed = now; pokes = [] }
    }

    // MARK: - Gesicht

    private func face(t: Double, now: Date) -> Face {
        let time = now.timeIntervalSinceReferenceDate
        let blend = Ease.outBack(Ease.segment(t, 0, 0.3), overshoot: 1.2)
        var f = Face.lerp(previous.face(previousVariant), mood.face(variant), blend)

        if animated {
            if mood == .idle {
                let quirk = quirk(time)
                f = .lerp(f, quirk.face, quirk.weight)
            }
            f = liven(f, t: t)
        }

        let sincePoke = now.timeIntervalSince(poke)
        if sincePoke < pokeKind.duration { f = pokeFace(f, sincePoke) }
        let sinceAnnoyed = now.timeIntervalSince(annoyed)
        if sinceAnnoyed < 2.8 {
            f = .lerp(f, .annoyed, Ease.segment(sinceAnnoyed, 0, 0.15) * (1 - Ease.segment(sinceAnnoyed, 2.3, 2.8)))
        }

        if mood == .explode {
            // Kurz vorm Platzen: Augen zukneifen.
            f = .lerp(f, .brace, Ease.segment(t, 0.4, 0.46))
        }
        if mood == .land {
            // Erschrocken im Fall, zugekniffen beim Aufprall, dann lacht er beim Schütteln.
            f = t < Self.landTime ? .surprised
                : t < 0.95 ? .brace
                : .lerp(Mood.laugh.face(0), Mood.idle.face(0), Ease.segment(t, 1.6, 2.0))
        }
        if let fid = fidget(t: t, sincePoke: sincePoke) {
            f = .lerp(f, fid.kind.face(local: fid.local), fid.weight)
        }

        guard animated else { return f }

        // Blinzeln, manchmal doppelt.
        f.eyeOpen *= 1 - min(1, 1.6 * blink(time))

        // Herumgucken, oder dahin, wo zuletzt getippt wurde.
        var look = glance(time)
        let sinceTouch = now.timeIntervalSince(touchTime)
        if let touch, sinceTouch < 2.5 {
            let dir = CGPoint(x: (touch.x - Rig.faceCenter.x) / 260, y: (touch.y - Rig.faceCenter.y) / 260)
            let w = 1 - Ease.segment(sinceTouch, 2.0, 2.5)
            look = CGPoint(x: look.x + (dir.x - look.x) * w, y: look.y + (dir.y - look.y) * w)
        }
        if mood == .nervous {
            // Blick huscht hektisch hin und her.
            look = CGPoint(x: sin(time * 2 * .pi * 1.3) > 0 ? 0.75 : -0.75, y: -0.15)
            f.wander = 1
        }
        if mood == .sleep {
            let breath = sin(t * 2 * .pi * 0.35)
            f.lipBottom += 14 * breath
            f.lipTop -= 6 * breath
        }
        f.lookX = min(max(f.lookX + look.x * f.wander, -1), 1)
        f.lookY = min(max(f.lookY + look.y * f.wander, -1), 1)
        return f
    }

    /// Was sich im Gesicht innerhalb einer Stimmung bewegt.
    private func liven(_ face: Face, t: Double) -> Face {
        var f = face
        switch (mood, variant) {
        case (.laugh, _):
            f.lipBottom += 28 * abs(sin(t * 2 * .pi * 2.6))
        case (.cheer, 1):
            // Singt beim Tanzen mit.
            f.lipBottom += 30 * sin(t * 2 * .pi * 3.2)
            f.mouthW += 20 * sin(t * 2 * .pi * 1.6)
        case (.sad, 1):
            // Zitternde Unterlippe beim Schluchzen.
            f.lipBottom += 10 * sin(t * 2 * .pi * 1.4)
            f.cornerL += 4 * sin(t * 2 * .pi * 9)
            f.cornerR += 4 * sin(t * 2 * .pi * 9 + 1)
        case (.smug, 1):
            // Wackelt vielsagend mit der Augenbraue.
            let burst = t.truncatingRemainder(dividingBy: 2.4) < 1.0 ? 1.0 : 0
            f.browRaiseR = -14 - 30 * abs(sin(t * 2 * .pi * 2.5)) * burst
        case (.drumroll, 1):
            f.lookX = sin(t * 2 * .pi * 0.9) > 0 ? 0.6 : -0.6
        case (.sleep, 1):
            // Schreckt kurz hoch.
            let cycle = t.truncatingRemainder(dividingBy: 3.2)
            f = .lerp(f, .surprised, sin(Ease.segment(cycle, 2.6, 3.1) * .pi))
        case (.deflate, _):
            f = .lerp(.surprised, f, Ease.segment(t, 0.15, 0.3))
        case (.dizzy, _):
            f = .lerp(.brace, f, Ease.segment(t, 0.3, 0.5))
        case (.melt, _):
            f.eyeOpen *= 1 - 0.3 * Ease.segment(t, 0.5, 1.5)
            f.cornerL += 8 * sin(t * 3)
            f.cornerR += 8 * sin(t * 3 + 2)
        case (.shrug, _):
            f.browY -= 14 * sin(Ease.segment(t.truncatingRemainder(dividingBy: variant == 1 ? 1.1 : 2.2), 0, 0.7) * .pi)
        default:
            break
        }
        return f
    }

    private func pokeFace(_ f: Face, _ s: Double) -> Face {
        switch pokeKind {
        case .wobble: .lerp(f, .surprised, 1 - Ease.segment(s, 0.3, 0.7))
        case .bonk: .lerp(f, .brace, 1 - Ease.segment(s, 0.6, 0.95))
        case .tickle: .lerp(f, Mood.laugh.face(1), Ease.segment(s, 0, 0.08) * (1 - Ease.segment(s, 1.2, 1.6)))
        case .hop: .lerp(f, Mood.cheer.face(0), sin(Ease.segment(s, 0, 0.9) * .pi))
        case .shy: .lerp(f, .shy, Ease.segment(s, 0, 0.2) * (1 - Ease.segment(s, 1.5, 2.0)))
        case .spin: .lerp(.lerp(f, .surprised, 1 - Ease.segment(s, 0.3, 0.6)), .dizzyLight, sin(Ease.segment(s, 0.6, 1.0) * .pi))
        }
    }

    /// Im Ruhezustand wechselt Wabbel alle paar Sekunden kurz den Ausdruck: grinsen, staunen, schmunzeln …
    private func quirk(_ time: Double) -> (face: Face, weight: Double) {
        let period = 3.9
        let k = Int(floor(time / period)), local = time - Double(k) * period
        guard noise(k, 20) > 0.3 else { return (Face(), 0) }
        let all = Face.quirks
        var i = Int(noise(k, 21) * Double(all.count)) % all.count
        if i == Int(noise(k - 1, 21) * Double(all.count)) % all.count { i = (i + 1) % all.count }
        let w = Ease.outCubic(Ease.segment(local, 0.2, 0.55)) * (1 - Ease.segment(local, period - 0.6, period - 0.1))
        return (all[i], w)
    }

    // MARK: - Langeweile

    fileprivate enum FidgetKind: CaseIterable {
        case yawn, armPlay, knock, stretch, hop, sneeze, lookAround, hum, scratch, raspberry, wiggle, balance

        var duration: Double {
            switch self {
            case .yawn: 2.4
            case .armPlay: 3.2
            case .knock: 2.9
            case .stretch: 2.6
            case .hop: 2.0
            case .sneeze: 2.2
            case .lookAround: 3.2
            case .hum: 3.4
            case .scratch: 2.6
            case .raspberry: 2.0
            case .wiggle: 1.8
            case .balance: 3.0
            }
        }

        func face(local l: Double) -> Face {
            var f = Face()
            f.wander = 0
            switch self {
            case .yawn:
                f.eyeOpen = 0; f.browY = -20; f.browTilt = 10
                f.mouthW = 120; f.cornerL = 0; f.cornerR = 0; f.lipTop = -70; f.lipBottom = 190
            case .armPlay:
                f.lookX = -0.85; f.lookY = 0.35; f.browY = -20
                f.mouthW = 70; f.cornerL = 0; f.cornerR = 0; f.lipTop = -20; f.lipBottom = 30; f.tongue = 0
            case .knock:
                f.browY = -25
                f.mouthW = 90; f.cornerL = 0; f.cornerR = 0; f.lipTop = -30; f.lipBottom = 40; f.tongue = 0
            case .stretch:
                f.eyeOpen = 0; f.browY = -24
                f.mouthW = 110; f.cornerL = 0; f.cornerR = 0; f.lipTop = -40; f.lipBottom = 110; f.tongue = 0.3
            case .hop:
                f.squint = 1; f.browY = -28
                f.mouthW = 200; f.cornerL = -26; f.cornerR = -26; f.lipTop = -4; f.lipBottom = 140
            case .sneeze:
                if l < 1.1 {
                    // Haaa…
                    let b = Ease.segment(l, 0, 1.1)
                    f.eyeOpen = 1 - 0.65 * b; f.browTilt = 18 * b; f.browY = -22 * b; f.lookY = -0.4
                    f.mouthW = 70; f.cornerL = 0; f.cornerR = 0; f.lipTop = -30 * b; f.lipBottom = 40 + 30 * b; f.tongue = 0
                } else if l < 1.5 {
                    // …tschi!
                    f.pinch = 1; f.browTilt = -10
                    f.mouthW = 160; f.cornerL = 0; f.cornerR = 0; f.lipTop = -40; f.lipBottom = 120; f.tongue = 0.3
                } else {
                    // Schnieft.
                    f.eyeOpen = 0.7; f.blush = 0.6
                    f.mouthW = 80; f.cornerL = 0; f.cornerR = 0; f.lipTop = -4; f.lipBottom = 12; f.tongue = 0
                }
            case .lookAround:
                f.lookX = l < 1.3 ? -0.9 : (l < 2.5 ? 0.9 : 0)
                f.eyeOpen = 0.72; f.browTilt = -8; f.browY = 6
                f.mouthW = 90; f.cornerL = 4; f.cornerR = 4; f.lipTop = 0; f.lipBottom = 8; f.tongue = 0
            case .hum:
                f.squint = 1; f.browY = -10
                f.mouthW = 70; f.cornerL = -6; f.cornerR = -6; f.lipTop = -14; f.lipBottom = 26 + 12 * sin(l * 2 * .pi * 2); f.tongue = 0
            case .scratch:
                f.browRaiseR = -32; f.browTilt = 6; f.lookX = 0.4; f.lookY = -0.6
                f.mouthW = 100; f.cornerL = 8; f.cornerR = -6; f.lipTop = 0; f.lipBottom = 10; f.tongue = 0
            case .raspberry:
                f.squint = 1; f.blush = 0.5; f.tongueOut = 1
                f.mouthW = 110; f.cornerL = 0; f.cornerR = 0; f.lipTop = -10; f.lipBottom = 30; f.tongue = 0
            case .wiggle:
                f.squint = 1; f.browY = -20
                f.mouthW = 210; f.cornerL = -20; f.cornerR = -20; f.lipTop = -4; f.lipBottom = 120
            case .balance:
                f.eyeScale = 1.08; f.lookY = 0.5; f.browTilt = 14
                f.mouthW = 110; f.cornerL = 6; f.cornerR = 6; f.lipTop = -14; f.lipBottom = 30; f.teeth = 1; f.tongue = 0
            }
            return f
        }
    }

    private struct Fidget { let kind: FidgetKind; let slot: Int; let local: Double; let weight: Double }

    /// Klopfzeiten innerhalb der Klopf-Einlage.
    private static let knockTimes = [0.7, 1.0, 1.3]

    /// Nach 6 Sekunden ohne Antippen wird Wabbel langweilig. Alle 5,5 Sekunden macht er dann etwas anderes.
    private func fidget(t: Double, sincePoke: Double) -> Fidget? {
        guard animated, mood == .idle else { return nil }
        let idle = min(t, sincePoke) - 6
        guard idle > 0 else { return nil }
        let slot = Int(idle / 5.5), local = idle - Double(slot) * 5.5
        let kind = fidgetKind(slot)
        guard local < kind.duration else { return nil }
        let weight: Double = switch kind {
        case .yawn: sin(Ease.segment(local, 0.2, 2.2) * .pi)
        case .armPlay: sin(Ease.segment(local, 0, 3.2) * .pi)
        case .knock: Ease.outBack(Ease.segment(local, 0, 0.3)) * (1 - Ease.segment(local, 2.4, 2.9))
        default: Ease.outCubic(Ease.segment(local, 0, 0.3)) * (1 - Ease.segment(local, kind.duration - 0.4, kind.duration))
        }
        return Fidget(kind: kind, slot: slot, local: local, weight: weight)
    }

    /// Zufällige Einlage, nie zweimal dieselbe hintereinander.
    private func fidgetKind(_ slot: Int) -> FidgetKind {
        let all = FidgetKind.allCases
        func raw(_ s: Int) -> Int { Int(noise(s, 9) * Double(all.count)) % all.count }
        var i = raw(slot)
        if slot > 0, i == raw(slot - 1) { i = (i + 1) % all.count }
        return all[i]
    }

    private func blink(_ time: Double) -> Double {
        let period = 3.4
        let k = Int(floor(time / period)), local = time - Double(k) * period
        let at = 0.3 + noise(k, 0) * 2.6
        var v = Self.pulse(local - at, 0.17)
        if noise(k, 1) < 0.25 { v = max(v, Self.pulse(local - at - 0.28, 0.17)) }
        return v
    }

    private func glance(_ time: Double) -> CGPoint {
        let period = 2.3
        let k = Int(floor(time / period)), local = time - Double(k) * period
        func target(_ k: Int) -> CGPoint {
            if noise(k, 2) < 0.35 { return .zero }
            return CGPoint(x: noise(k, 3) * 1.4 - 0.7, y: noise(k, 4) * 0.8 - 0.4)
        }
        let a = target(k - 1), b = target(k)
        let f = Ease.outCubic(Ease.segment(local, 0, 0.16))
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    /// Im Ruhezustand neigt er sich mal hierhin, mal dorthin.
    private func lean(_ t: Double) -> Double {
        let period = 3.9
        let k = Int(floor(t / period)), local = t - Double(k) * period
        func target(_ k: Int) -> Double { noise(k, 30) < 0.4 ? 0 : noise(k, 31) * 9 - 4.5 }
        let a = target(k - 1), b = target(k)
        return a + (b - a) * Ease.inOutCubic(Ease.segment(local, 0, 0.8))
    }

    private func noise(_ k: Int, _ salt: UInt64) -> Double {
        var g = SplitMix64(seed: UInt64(bitPattern: Int64(k)) &* 31 &+ seed &* 7 &+ salt)
        return Double(g.next() >> 11) / Double(1 << 53)
    }

    private static func pulse(_ x: Double, _ duration: Double) -> Double {
        guard x > 0, x < duration else { return 0 }
        return sin(x / duration * .pi)
    }

    // MARK: - Bewegung

    private struct Motion {
        var sx = 1.0, sy = 1.0, rotation = 0.0, dx = 0.0, dy = 0.0, opacity = 1.0
        var armL = 0.0, armR = 0.0, feet = 0.0
        /// Nur der rechte Fuß, zum Treten.
        var kick = 0.0
        /// Kommt näher an die Scheibe.
        var closer = 0.0
        /// Dreht die ganze Figur samt Füßen um ihre Mitte, z. B. für einen Salto.
        var spin = 0.0
        /// Verkleinert die ganze Figur, z. B. beim Luftablassen.
        var shrink = 1.0
        /// Arme vor dem Körper statt dahinter.
        var armsFront = false
        /// Aufgeheizt kurz vorm Platzen.
        var glow = 0.0
        /// Wie weit das Schild schon hochgehalten wird (0 bis 1).
        var signUp = 0.0
    }

    private func motion(t: Double, sincePoke: Double) -> Motion {
        var m = Motion()
        // Grundwabbeln: Breite und Höhe schwingen gegenläufig, die Arme pendeln mit.
        let breathe = sin(t * 2 * .pi * 0.9)
        m.sx = 1 + 0.022 * breathe
        m.sy = 1 - 0.022 * breathe
        m.rotation = 1.2 * sin(t * 2 * .pi * 0.45)
        m.armL = 4 * sin(t * 2 * .pi * 0.9 + 0.8)
        m.armR = -m.armL

        switch mood {
        case .idle:
            if animated { m.rotation += lean(t) }
        case .cheer:
            let up = Ease.outBack(Ease.segment(t, 0, 0.3))
            switch variant {
            case 1:
                // Tanzt: Hüftschwung, abwechselnd Arme hoch, Füße tippen.
                let beat = t * 2 * .pi * 1.6
                m.rotation += 7 * sin(beat)
                m.dx = 0.03 * sin(beat)
                m.dy = 0.04 * abs(sin(beat))
                m.sy *= 1 + 0.04 * abs(cos(beat))
                m.armL = up * (55 + 75 * max(0, sin(beat)))
                m.armR = -up * (55 + 75 * max(0, -sin(beat)))
                m.feet = 12 * sin(beat)
            case 2:
                // Salto, danach kleine Freudenhüpfer.
                let jump = Ease.segment(t, 0.05, 0.8)
                m.dy = 0.5 * sin(jump * .pi)
                m.spin = -360 * Ease.inOutCubic(Ease.segment(t, 0.12, 0.72))
                m.shrink = 1 - 0.12 * sin(jump * .pi)
                m.armL = up * 130
                m.armR = -up * 130
                m.feet = 12 * sin(jump * .pi)
                let land = Ease.wobble(Ease.segment(t, 0.8, 1.5), frequency: 3, decay: 4)
                m.sy *= 1 - 0.18 * land
                m.sx *= 1 + 0.14 * land
                if t > 1.2 {
                    let phase = ((t - 1.2) * 1.8).truncatingRemainder(dividingBy: 1)
                    m.dy += 0.1 * sin(phase * .pi)
                    m.armL = 120 + 25 * sin(t * 2 * .pi * 3)
                    m.armR = -(120 + 25 * sin(t * 2 * .pi * 3 + .pi))
                }
            case 3:
                // Siegerfaust: abwechselnd Arme hochreißen.
                let beat = t * 2 * .pi * 2.2
                m.armL = up * (35 + 110 * max(0, sin(beat)))
                m.armR = -up * (35 + 110 * max(0, -sin(beat)))
                m.dy = 0.05 * abs(sin(beat))
                m.sy *= 1 + 0.05 * abs(sin(beat))
                m.sx *= 1 - 0.03 * abs(sin(beat))
                m.rotation += 5 * sin(beat / 2)
            default:
                // Sprünge mit Stauchen beim Aufkommen, Arme wedeln oben.
                let phase = (t * 1.6).truncatingRemainder(dividingBy: 1)
                let height = sin(phase * .pi)
                m.dy = 0.2 * height
                let squash = max(0, 1 - phase * 6) + max(0, (phase - 0.85) * 6)
                m.sy *= 1 - 0.12 * squash + 0.06 * height
                m.sx *= 1 + 0.12 * squash - 0.04 * height
                m.armL = up * (120 + 22 * sin(t * 2 * .pi * 3.2))
                m.armR = -up * (120 + 22 * sin(t * 2 * .pi * 3.2 + .pi))
                m.feet = 10 * height
            }
        case .laugh:
            let shake = abs(sin(t * 2 * .pi * 2.6))
            m.dy = 0.03 * shake
            m.sy *= 1 - 0.05 * shake
            m.sx *= 1 + 0.04 * shake
            switch variant {
            case 1:
                // Kippt vor Lachen nach hinten und strampelt.
                let tip = Ease.outBack(Ease.segment(t, 0, 0.4))
                m.rotation += -13 * tip + 4 * sin(t * 2 * .pi * 2.6)
                m.armL = 60 + 35 * sin(t * 2 * .pi * 4)
                m.armR = -(60 + 35 * sin(t * 2 * .pi * 4 + 1.5))
                m.feet = 16 * sin(t * 2 * .pi * 3.2)
                m.kick = -12 * tip + 14 * sin(t * 2 * .pi * 3.2 + 1)
            case 2:
                // Krümmt sich und haut sich auf den Schenkel.
                let bend = Ease.outCubic(Ease.segment(t, 0, 0.35))
                m.rotation += 11 * bend + 2 * sin(t * 2 * .pi * 2.6)
                m.sy *= 1 - 0.05 * bend
                m.armR = -80 * max(0, sin(t * 2 * .pi * 2.2)) * bend
                m.armL = -14 + 8 * shake
            default:
                // Kurzes, schnelles Hüpfen, Arme halten den Bauch.
                m.rotation += 3.5 * sin(t * 2 * .pi * 1.3)
                m.armL = -14 + 10 * shake
                m.armR = 14 - 10 * shake
            }
        case .shock:
            let entry = Ease.outBack(Ease.segment(t, 0, 0.25), overshoot: 2.5)
            switch variant {
            case 1:
                // Springt erschrocken zurück und bleibt stocksteif.
                let back = Ease.outCubic(Ease.segment(t, 0, 0.3))
                m.dx = -0.12 * back + 0.005 * sin(t * 2 * .pi * 14)
                m.dy = 0.14 * sin(Ease.segment(t, 0, 0.3) * .pi)
                m.rotation += -8 * back + 8 * Ease.outCubic(Ease.segment(t, 0.3, 0.8))
                m.sx *= 1 - 0.06 * entry
                m.sy *= 1 + 0.06 * entry
                m.armL = 100 * entry + 3 * sin(t * 2 * .pi * 11)
                m.armR = -100 * entry - 3 * sin(t * 2 * .pi * 11 + 1)
                m.feet = 10 * back
            case 2:
                // Schießt in die Höhe wie eine Sprungfeder.
                let boing = Ease.wobble(Ease.segment(t, 0, 1.6), frequency: 4, decay: 3.5)
                m.sy *= 1 + 0.22 * max(boing, -0.5) + 0.06 * entry
                m.sx *= 1 - 0.14 * boing
                m.armL = 150 * entry
                m.armR = -150 * entry
                m.dx = 0.004 * sin(t * 2 * .pi * 15)
            default:
                // Zuckt hoch, Arme fliegen nach oben, danach Zittern.
                m.dy = 0.1 * sin(Ease.segment(t, 0, 0.35) * .pi)
                m.sy *= 1 + 0.05 * entry
                m.sx *= 1 - 0.04 * entry
                m.dx = 0.006 * sin(t * 2 * .pi * 13)
                m.armL = 75 * entry + 4 * sin(t * 2 * .pi * 9)
                m.armR = -75 * entry - 4 * sin(t * 2 * .pi * 9 + 1)
            }
        case .sad:
            // Sackt zusammen.
            let droop = Ease.outCubic(Ease.segment(t, 0, 0.7))
            m.sx = 1 + 0.045 * droop + 0.01 * breathe
            m.sy = 1 - 0.06 * droop - 0.01 * breathe
            m.armL = -10 * droop
            m.armR = 10 * droop
            switch variant {
            case 1:
                // Schluchzt.
                let sob = pow(max(0, sin(t * 2 * .pi * 1.4)), 2)
                m.sy *= 1 - 0.035 * sob
                m.sx *= 1 + 0.02 * sob
                m.dy = 0.012 * sob
                m.rotation = 1.5 * sin(t * 2 * .pi * 0.7)
                m.armL = -16 * droop + 6 * sob
                m.armR = 16 * droop - 6 * sob
            case 2:
                // Seufzt tief und scharrt mit dem Fuß.
                let cycle = t.truncatingRemainder(dividingBy: 3.2)
                let breath = Ease.inOutCubic(Ease.segment(cycle, 0.2, 1.3)) * (1 - Ease.inOutCubic(Ease.segment(cycle, 1.4, 2.4)))
                m.sy *= 1 + 0.07 * breath
                m.sx *= 1 - 0.03 * breath
                m.armL += 18 * breath
                m.armR -= 18 * breath
                m.rotation = 2 * sin(t * 2 * .pi * 0.25)
                m.kick = 14 * sin(Ease.segment(cycle, 2.4, 3.2) * .pi * 2)
            default:
                m.rotation = 2.5 * sin(t * 2 * .pi * 0.25)
            }
        case .smug:
            // Arme in die Hüften.
            let lean = Ease.outCubic(Ease.segment(t, 0, 0.4))
            m.armL = -18 * lean + 3 * sin(t * 2 * .pi * 0.9)
            m.armR = 18 * lean
            if variant == 1 {
                // Nickt selbstzufrieden vor sich hin.
                m.rotation += -3 * lean + 2.5 * sin(t * 2 * .pi * 1.1)
                m.sy *= 1 + 0.02 * sin(t * 2 * .pi * 2.2)
            } else {
                m.rotation += 4 * lean
            }
        case .explode:
            // Aufblasen mit immer stärkerem Zittern, kurz zusammenkneifen, dann Platzen.
            let inflate = Ease.inCubic(Ease.segment(t, 0, 0.42))
            let squeeze = Ease.outCubic(Ease.segment(t, 0.42, Self.popTime))
            m.sx *= (1 + 0.3 * inflate) * (1 - 0.07 * squeeze)
            m.sy *= (1 + 0.24 * inflate) * (1 - 0.15 * squeeze)
            let shake = inflate * (1 - squeeze) + 1.5 * squeeze
            m.dx = 0.03 * shake * sin(t * 2 * .pi * 22)
            m.rotation += 4 * shake * sin(t * 2 * .pi * 17)
            m.armL = 95 * inflate - 40 * squeeze + 15 * squeeze * sin(t * 2 * .pi * 14)
            m.armR = -m.armL
            m.glow = inflate
            m.opacity = t < Self.popTime ? 1 : 0
        case .present:
            let up = Ease.outBack(Ease.segment(t, 0, 0.3), overshoot: 2)
            switch variant {
            case 1:
                // Verbeugt sich und zeigt mit einem Arm zur Seite.
                let bow = sin(Ease.segment(t, 0, 0.6) * .pi)
                m.rotation += 9 * bow
                m.sy *= 1 - 0.05 * bow
                m.armR = -up * (95 + 8 * sin(t * 2 * .pi * 1.4))
                m.armL = -18 * up
                m.dy = 0.03 * abs(sin(t * 2 * .pi * 1.1)) * Ease.segment(t, 0.6, 0.9)
            case 2:
                // Jazz Hands.
                m.armL = up * (135 + 10 * sin(t * 2 * .pi * 9))
                m.armR = -up * (135 + 10 * sin(t * 2 * .pi * 9 + 1))
                m.dx = 0.02 * sin(t * 2 * .pi * 2)
                m.rotation += 5 * sin(t * 2 * .pi * 2)
                m.dy = 0.08 * sin(Ease.segment(t, 0, 0.3) * .pi)
            default:
                m.armL = up * (125 + 6 * sin(t * 2 * .pi * 1.8))
                m.armR = -up * (125 + 6 * sin(t * 2 * .pi * 1.8 + 1))
                m.dy = 0.05 * abs(sin(t * 2 * .pi * 1.1)) + 0.08 * sin(Ease.segment(t, 0, 0.3) * .pi)
            }
        case .drumroll:
            if variant == 1 {
                // Hibbelt auf den Zehenspitzen.
                let hop = abs(sin(t * 2 * .pi * 4.5))
                m.dy = 0.025 * hop
                m.sy *= 1 + 0.04 * hop
                m.feet = 8 * sin(t * 2 * .pi * 4.5)
                m.armL = 55 + 18 * sin(t * 2 * .pi * 10)
                m.armR = -(55 + 18 * sin(t * 2 * .pi * 10 + .pi))
            } else {
                m.armL = 35 + 28 * sin(t * 2 * .pi * 8)
                m.armR = -(35 + 28 * sin(t * 2 * .pi * 8 + .pi))
                m.sy *= 1 + 0.02 * sin(t * 2 * .pi * 16)
                m.dx = 0.004 * sin(t * 2 * .pi * 19)
            }
        case .nervous:
            if variant == 1 {
                // Macht sich klein und knetet die Hände.
                m.armsFront = true
                m.sy *= 0.9
                m.sx *= 1.04
                m.dx = 0.005 * sin(t * 2 * .pi * 13)
                m.armL = -70 + 8 * sin(t * 2 * .pi * 6)
                m.armR = 70 + 8 * sin(t * 2 * .pi * 6 + 2)
                m.rotation += 2 * sin(t * 2 * .pi * 0.8)
            } else {
                m.dx = 0.008 * sin(t * 2 * .pi * 15)
                m.sy *= 0.97
                m.armL = 22 + 6 * sin(t * 2 * .pi * 11)
                m.armR = -(22 + 6 * sin(t * 2 * .pi * 11 + 1))
                m.feet = 4 * sin(t * 2 * .pi * 7)
            }
        case .sleep:
            let slow = sin(t * 2 * .pi * 0.35)
            m.sx = 1 + 0.035 * slow
            m.sy = 1 - 0.035 * slow
            m.armL = -6
            m.armR = 6
            if variant == 1 {
                // Nickt immer wieder ein und schreckt hoch.
                let cycle = t.truncatingRemainder(dividingBy: 3.2)
                let nod = Ease.inCubic(Ease.segment(cycle, 0, 2.6)) * (1 - Ease.outBack(Ease.segment(cycle, 2.6, 2.85)))
                m.rotation = 13 * nod
                m.sy *= 1 - 0.04 * nod
                let jolt = sin(Ease.segment(cycle, 2.6, 2.9) * .pi)
                m.dy = 0.04 * jolt
                m.armL += 30 * jolt
                m.armR -= 30 * jolt
            } else {
                m.rotation = 6 * Ease.outCubic(Ease.segment(t, 0, 0.8)) + 1 * slow
            }
        case .kick:
            let windup = Ease.outCubic(Ease.segment(t, 0, 0.35))
            let strike = Ease.outCubic(Ease.segment(t, 0.35, Self.kickImpact + 0.03))
            let recover = Ease.outCubic(Ease.segment(t, 0.65, 1.05))
            m.kick = (28 * windup * (1 - strike) - 80 * strike) * (1 - recover)
            m.rotation += (-9 * windup * (1 - strike) + 12 * strike) * (1 - recover)
            m.dx = 0.07 * strike * (1 - recover)
            m.sy *= 1 - 0.05 * windup * (1 - strike)
            m.armL = (20 * windup + 70 * strike) * (1 - recover)
            m.armR = -(20 * windup + 40 * strike) * (1 - recover)
        case .wave:
            let up = Ease.outBack(Ease.segment(t, 0, 0.3))
            m.armR = -up * (140 + 25 * sin(t * 2 * .pi * 2.4))
            if variant == 1 {
                // Winkt mit beiden Armen und hüpft dabei.
                m.armL = up * (140 + 25 * sin(t * 2 * .pi * 2.4 + .pi))
                m.dy = 0.04 * abs(sin(t * 2 * .pi * 1.2))
            }
            m.rotation += 3 * sin(t * 2 * .pi * 1.2)
        case .judge:
            let up = Ease.outBack(Ease.segment(t, 0, 0.35))
            if variant == 1 {
                // Wippt ungeduldig mit dem Hammer.
                m.armR = -up * (135 - 30 * abs(sin(t * 2 * .pi * 1.5)))
                m.rotation += 2 * sin(t * 2 * .pi * 0.5)
            } else {
                m.armR = -up * (150 + 4 * sin(t * 2 * .pi * 7))
            }
            m.armL = -10
        case .verdict:
            let raise = Ease.outCubic(Ease.segment(t, 0, 0.1))
            let slam = Ease.inCubic(Ease.segment(t, 0.1, 0.18))
            m.armR = -(150 + 15 * raise - 125 * slam)
            m.armL = -10 + 30 * slam
            let hit = Ease.wobble(Ease.segment(t, 0.18, 0.8), frequency: 3, decay: 4)
            m.sy *= 1 - 0.1 * hit
            m.sx *= 1 + 0.08 * hit
        case .coverEyes:
            m.armsFront = true
            let cover = Ease.outBack(Ease.segment(t, 0, 0.3))
            // Alle paar Sekunden linst er unter einem Arm durch.
            let cycle = t.truncatingRemainder(dividingBy: 2.6)
            let peek = t > 1 ? sin(Ease.segment(cycle, 1.6, 2.3) * .pi) : 0
            if variant == 1 {
                // Zittert vor Angst und linst rechts.
                let tremble = 3 * sin(t * 2 * .pi * 12)
                m.armL = -cover * 139 + tremble
                m.armR = cover * (139 - 45 * peek) + tremble
                m.dx = 0.004 * sin(t * 2 * .pi * 14)
            } else {
                m.armL = -cover * (139 - 45 * peek)
                m.armR = cover * 139
                m.rotation += 2 * sin(t * 2 * .pi * 1.4)
            }
        case .land:
            let fall = Ease.segment(t, 0, Self.landTime)
            m.dy = 1.6 * (1 - fall * fall)
            m.armL = 120 * (1 - fall)
            m.armR = -m.armL
            let impact = Ease.wobble(Ease.segment(t, Self.landTime, 1.0), frequency: 3, decay: 4)
            m.sy *= 1 - 0.28 * impact
            m.sx *= 1 + 0.22 * impact
            // Schüttelt sich wie ein nasser Hund.
            let shake = Ease.segment(t, 1.0, 1.7)
            if shake > 0, shake < 1 {
                let w = sin(shake * .pi * 9) * (1 - shake)
                m.rotation += 10 * w
                m.armL += 35 * w
                m.armR += 35 * w
                m.sx *= 1 + 0.05 * abs(w)
            }
        case .shrug:
            let cycle = t.truncatingRemainder(dividingBy: variant == 1 ? 1.1 : 2.2)
            let s = sin(Ease.segment(cycle, 0, 0.7) * .pi)
            let open = Ease.outBack(Ease.segment(t, 0, 0.3))
            m.armL = open * 45 + 30 * s
            m.armR = -(open * 45 + 30 * s)
            m.sy *= 1 + 0.05 * s
            m.dy = 0.02 * s
            // Zweite Spielart: schüttelt dabei ratlos den Kopf.
            m.rotation += variant == 1 ? 4 * sin(t * 2 * .pi * 0.9) : 3 * open
        case .melt:
            // Zuckt kurz und zerfließt dann langsam zur Pfütze.
            let k = Ease.inOutCubic(Ease.segment(t, 0.15, 1.5))
            let jolt = sin(Ease.segment(t, 0, 0.2) * .pi)
            m.sy *= (1 + 0.06 * jolt) * (1 - 0.6 * k)
            m.sx *= (1 - 0.04 * jolt) * (1 + 0.5 * k + 0.03 * sin(t * 3) * k)
            m.rotation *= 1 - k
            m.armL = 40 * jolt - 30 * k
            m.armR = -m.armL
            m.feet = 10 * k
        case .deflate:
            // Pfft: schwirrt wild herum, schrumpft und landet schlapp.
            m.sx *= 1 + 0.08 * sin(Ease.segment(t, 0, 0.25) * .pi)
            let fly = Ease.segment(t, 0.25, 1.65)
            let flying = fly > 0 && fly < 1
            if flying {
                let ft = t - 0.25
                m.dx = 0.28 * sin(ft * 7.3) * sin(fly * .pi)
                m.dy = 0.35 * abs(sin(ft * 5.1)) * sin(fly * .pi)
                m.rotation += 35 * sin(ft * 11) * (1 - fly)
                m.sx *= 1 + 0.06 * sin(ft * 40)
            }
            m.shrink = 1 - 0.38 * Ease.outCubic(fly)
            let flat = Ease.segment(t, 1.65, 1.8)
            let flop = Ease.wobble(Ease.segment(t, 1.65, 2.4), frequency: 2.5, decay: 4)
            m.sy *= 1 - 0.25 * flat - 0.1 * flop
            m.sx *= 1 + 0.15 * flat
            m.armL = flying ? 60 + 40 * sin(t * 30) : -20 * flat
            m.armR = flying ? -(60 + 40 * sin(t * 30 + 1)) : 20 * flat
        case .holdSign:
            // Reißt das Schild hoch und wippt stolz. Die Arme bleiben genau bei 150°, damit die Stangen senkrecht stehen.
            let up = Ease.outBack(Ease.segment(t, 0, 0.35), overshoot: 1.6)
            m.signUp = min(1, max(0, up))
            m.armL = 150 * up
            m.armR = -150 * up
            m.dy = 0.02 * abs(sin(t * 2 * .pi * 0.8)) * Ease.segment(t, 0.4, 0.8)
            m.rotation = 0
        case .dizzy:
            // Bekommt eins ab und torkelt im Kreis.
            let hit = Ease.wobble(Ease.segment(t, 0, 0.8), frequency: 3, decay: 4)
            m.sy *= 1 - 0.18 * hit
            m.sx *= 1 + 0.14 * hit
            let sway = Ease.segment(t, 0.3, 0.8)
            m.rotation += sway * 9 * sin(t * 2 * .pi * 0.75)
            m.dx = sway * 0.03 * cos(t * 2 * .pi * 0.75)
            m.armL = 30 + 25 * sin(t * 2 * .pi * 0.75 + 1)
            m.armR = -(30 + 25 * sin(t * 2 * .pi * 0.75 + 2.5))
            m.feet = 6 * sin(t * 2 * .pi * 0.75)
        }

        if let fid = fidget(t: t, sincePoke: sincePoke) { applyFidget(fid, to: &m) }
        if sincePoke < pokeKind.duration { applyPoke(sincePoke, to: &m) }
        return m
    }

    /// Langeweile-Einlagen: gähnen, klopfen, strecken, niesen, summen …
    private func applyFidget(_ fid: Fidget, to m: inout Motion) {
        let l = fid.local, w = fid.weight
        switch fid.kind {
        case .yawn:
            m.sy *= 1 + 0.09 * w
            m.sx *= 1 - 0.04 * w
            m.armL += 110 * w
            m.armR -= 110 * w
        case .armPlay:
            m.armL += 50 * w + 30 * w * sin(l * 2 * .pi * 2.2)
            m.rotation -= 4 * w
        case .knock:
            m.closer = 0.22 * w
            let hits = Self.knockTimes.reduce(0) { $0 + Self.pulse(l - $1, 0.14) }
            m.armR = -(100 + 35 * hits) * w
            m.armL = 10 * w
        case .stretch:
            let up = sin(Ease.segment(l, 0, 2.0) * .pi)
            m.sy *= 1 + 0.15 * up
            m.sx *= 1 - 0.07 * up
            m.dy += 0.02 * up
            m.armL += 150 * up
            m.armR -= 150 * up
            let shake = Ease.wobble(Ease.segment(l, 2.0, 2.6), frequency: 4, decay: 3)
            m.sx *= 1 + 0.08 * shake
            m.sy *= 1 - 0.08 * shake
        case .hop:
            let h = [0.2, 0.75, 1.3].reduce(0) { $0 + Self.pulse(l - $1, 0.45) }
            m.dy += 0.13 * h
            m.sy *= 1 + 0.05 * h
            m.armL += 45 * h
            m.armR -= 45 * h
            m.feet += 10 * h
        case .sneeze:
            let build = l < 1.1 ? Ease.inCubic(Ease.segment(l, 0, 1.1)) : 0
            let achoo = Ease.wobble(Ease.segment(l, 1.1, 1.9), frequency: 2, decay: 4)
            m.rotation += -7 * build + 12 * achoo
            m.sy *= 1 + 0.07 * build - 0.1 * max(0, achoo)
            m.sx *= 1 + 0.08 * max(0, achoo)
            m.dx += 0.03 * max(0, achoo)
            m.armL += 30 * build + 40 * abs(achoo)
            m.armR -= 30 * build + 40 * abs(achoo)
        case .lookAround:
            // Späht nach links, dann nach rechts, Hand über den Augen.
            let side = -Ease.inOutCubic(Ease.segment(l, 0, 0.3)) + 2 * Ease.inOutCubic(Ease.segment(l, 1.2, 1.5))
                - Ease.inOutCubic(Ease.segment(l, 2.4, 2.8))
            m.rotation += 5 * side * w
            m.dx += 0.02 * side * w
            m.armL += 90 * max(0, -side) * w
            m.armR -= 90 * max(0, side) * w
        case .hum:
            let beat = l * 2 * .pi * 0.9
            m.rotation += 6 * sin(beat) * w
            m.dx += 0.015 * sin(beat) * w
            m.feet += 8 * sin(beat * 2) * w
            m.armL += 20 * sin(beat) * w
            m.armR += 20 * sin(beat) * w
        case .scratch:
            m.armR = m.armR * (1 - w) - (150 + 12 * sin(l * 2 * .pi * 5)) * w
            m.rotation -= 4 * w
        case .raspberry:
            let shake = sin(Ease.segment(l, 0.3, 1.5) * .pi)
            m.rotation += 4 * sin(l * 2 * .pi * 7) * shake
            m.dx += 0.004 * sin(l * 2 * .pi * 14) * shake
        case .wiggle:
            let j = sin(l * 2 * .pi * 6) * w
            m.sx *= 1 + 0.08 * j
            m.sy *= 1 - 0.08 * j
            m.armL += 35 * j
            m.armR += 35 * j
            m.rotation += 3 * j
        case .balance:
            // Steht auf einem Bein, kippt fast um und fängt sich.
            m.kick = -32 * w
            let tip = Ease.segment(l, 1.6, 2.3)
            let wob = sin(l * 2 * .pi * 1.3) * (1 + 1.5 * sin(tip * .pi))
            m.rotation += (-5 + 4 * wob) * w
            m.armL += (70 - 25 * wob) * w
            m.armR -= (70 + 25 * wob) * w
        }
    }

    /// Antippen: je nach Stelle und Zufall ein anderer Wackler.
    private func applyPoke(_ s: Double, to m: inout Motion) {
        switch pokeKind {
        case .wobble:
            // Pudding-Wackler, der schnell abklingt.
            let w = Ease.wobble(s / 1.2, frequency: 4, decay: 5)
            m.sx *= 1 + 0.12 * w
            m.sy *= 1 - 0.12 * w
            m.armL += 25 * w
            m.armR -= 25 * w
        case .bonk:
            // Eins auf den Deckel: wird plattgedrückt.
            let w = Ease.wobble(s, frequency: 3, decay: 5)
            let squash = max(0, 1 - s / 0.25)
            m.sy *= 1 - 0.18 * squash - 0.08 * w
            m.sx *= 1 + 0.14 * squash + 0.06 * w
            m.armL += 40 * squash
            m.armR -= 40 * squash
        case .tickle:
            // Kitzelig: kichert und windet sich.
            let fade = 1 - Ease.segment(s, 1.1, 1.6)
            let shake = abs(sin(s * 2 * .pi * 5)) * fade
            m.dy += 0.03 * shake
            m.rotation += 5 * sin(s * 2 * .pi * 3) * fade
            m.sy *= 1 - 0.05 * shake
            m.armL = m.armL * (1 - fade) + (-14 + 12 * shake) * fade
            m.armR = m.armR * (1 - fade) + (14 - 12 * shake) * fade
        case .hop:
            let jump = sin(Ease.segment(s, 0, 0.55) * .pi)
            let land = Ease.wobble(Ease.segment(s, 0.55, 0.9), frequency: 2, decay: 4)
            m.dy += 0.2 * jump
            m.sy *= 1 - 0.14 * land + 0.06 * jump
            m.sx *= 1 + 0.1 * land
            m.armL += 70 * jump
            m.armR -= 70 * jump
            m.feet += 10 * jump
        case .shy:
            // Wird verlegen und dreht den Fuß.
            let w = Ease.outCubic(Ease.segment(s, 0, 0.25)) * (1 - Ease.segment(s, 1.5, 2.0))
            m.rotation -= 5 * w
            m.sy *= 1 - 0.03 * w
            m.kick += 10 * sin(s * 2 * .pi * 1.4) * w
            m.armL -= 15 * w
            m.armR += 15 * w
        case .spin:
            // Pirouette in der Luft.
            let jump = sin(Ease.segment(s, 0, 0.7) * .pi)
            let land = Ease.wobble(Ease.segment(s, 0.7, 1.0), frequency: 2, decay: 4)
            m.dy += 0.22 * jump
            m.spin += 360 * Ease.inOutCubic(Ease.segment(s, 0.05, 0.65))
            m.sy *= 1 - 0.14 * land
            m.sx *= 1 + 0.1 * land
            m.armL += 60 * jump
            m.armR -= 60 * jump
        }
    }
}

// MARK: - Aufbau

/// Lage aller Teile auf der 1254er-Vorlage, aus der die Bilder geschnitten sind.
private enum Rig {
    static let origin = CGPoint(x: 90, y: 140)
    static let canvas = CGSize(width: 1060, height: 970)

    static let body = CGRect(x: 233, y: 150, width: 787, height: 775)
    static let armL = CGRect(x: 100, y: 548, width: 206, height: 273)
    static let armR = CGRect(x: 934, y: 548, width: 206, height: 273)
    static let footL = CGRect(x: 290, y: 880, width: 285, height: 221)
    static let footR = CGRect(x: 665, y: 880, width: 285, height: 221)
    static let ground = 1092.0

    /// Schultern: hier sitzt die Spitze des Tropfens am Körper.
    static let shoulderL = UnitPoint(x: 0.86, y: 0.07)
    static let shoulderR = UnitPoint(x: 0.14, y: 0.07)
    /// Unterkante des Körpers, um die gestaucht und geneigt wird.
    static let bodyBottom = UnitPoint(x: (626 - origin.x) / canvas.width, y: (925 - origin.y) / canvas.height)
    /// Mitte des Körpers, um die er Saltos schlägt.
    static let bodyCenter = UnitPoint(x: (626 - origin.x) / canvas.width, y: (560 - origin.y) / canvas.height)

    static let eyeL = CGPoint(x: 466, y: 508)
    static let eyeR = CGPoint(x: 770, y: 508)
    static let browL = CGPoint(x: 480, y: 302)
    static let browR = CGPoint(x: 774, y: 302)
    static let mouth = CGPoint(x: 618, y: 676)
    static let faceCenter = CGPoint(x: 618, y: 520)
}

/// Alle Stellschrauben eines Gesichtsausdrucks. Zwischen zwei Ausdrücken wird weich überblendet.
private struct Face {
    var eyeOpen = 1.0
    var eyeScale = 1.0
    var pupil = 1.0
    /// 1 = Augen vor Freude zu ^^
    var squint = 0.0
    /// 1 = Augen fest zugekniffen > <
    var pinch = 0.0
    var lookX = 0.0, lookY = 0.0
    /// Wie stark der Blick von selbst wandert.
    var wander = 1.0
    var browY = 0.0
    /// Positiv: innen hoch (besorgt), negativ: innen runter (böse).
    var browTilt = 0.0
    /// Rechte Braue zusätzlich hoch.
    var browRaiseR = 0.0
    var mouthW = 170.0
    var cornerL = -12.0, cornerR = -12.0
    var lipTop = 4.0, lipBottom = 95.0
    var tongue = 1.0
    /// Zusammengebissene Zähne
    var teeth = 0.0
    /// Schweißtropfen an den Schläfen
    var sweat = 0.0
    /// Rote Bäckchen
    var blush = 0.0
    /// Tränen laufen aus den Augen.
    var tears = 0.0
    /// Streckt die Zunge raus.
    var tongueOut = 0.0
    /// Rechtes Auge zwinkert ^
    var winkR = 0.0
    /// Spiralaugen
    var dizzy = 0.0

    static func lerp(_ a: Face, _ b: Face, _ t: Double) -> Face {
        func l(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        var f = Face()
        f.eyeOpen = l(a.eyeOpen, b.eyeOpen); f.eyeScale = l(a.eyeScale, b.eyeScale)
        f.pupil = l(a.pupil, b.pupil); f.squint = l(a.squint, b.squint); f.pinch = l(a.pinch, b.pinch)
        f.lookX = l(a.lookX, b.lookX); f.lookY = l(a.lookY, b.lookY); f.wander = l(a.wander, b.wander)
        f.browY = l(a.browY, b.browY); f.browTilt = l(a.browTilt, b.browTilt); f.browRaiseR = l(a.browRaiseR, b.browRaiseR)
        f.mouthW = l(a.mouthW, b.mouthW); f.cornerL = l(a.cornerL, b.cornerL); f.cornerR = l(a.cornerR, b.cornerR)
        f.lipTop = l(a.lipTop, b.lipTop); f.lipBottom = l(a.lipBottom, b.lipBottom); f.tongue = l(a.tongue, b.tongue)
        f.teeth = l(a.teeth, b.teeth); f.sweat = l(a.sweat, b.sweat)
        f.blush = l(a.blush, b.blush); f.tears = l(a.tears, b.tears); f.tongueOut = l(a.tongueOut, b.tongueOut)
        f.winkR = l(a.winkR, b.winkR); f.dizzy = l(a.dizzy, b.dizzy)
        return f
    }

    static let surprised: Face = {
        var f = Face()
        f.eyeScale = 1.1; f.pupil = 0.8; f.browY = -38; f.wander = 0
        f.mouthW = 80; f.cornerL = 0; f.cornerR = 0; f.lipTop = -40; f.lipBottom = 60; f.tongue = 0.3
        return f
    }()

    static let brace: Face = {
        var f = Face()
        f.pinch = 1; f.wander = 0; f.browTilt = -16; f.browY = 22
        f.mouthW = 150; f.cornerL = 10; f.cornerR = 10; f.lipTop = -10; f.lipBottom = 30; f.tongue = 0
        return f
    }()

    static let shy: Face = {
        var f = Face()
        f.blush = 1; f.eyeOpen = 0.85; f.lookX = -0.6; f.lookY = 0.45; f.wander = 0; f.browTilt = 10
        f.mouthW = 110; f.cornerL = -14; f.cornerR = -14; f.lipTop = 0; f.lipBottom = 26; f.tongue = 0
        return f
    }()

    static let dizzyLight: Face = {
        var f = Face()
        f.dizzy = 1; f.wander = 0; f.browY = -10
        f.mouthW = 150; f.cornerL = -14; f.cornerR = -4; f.lipTop = -4; f.lipBottom = 50
        return f
    }()

    /// Kleine Ausdrücke, die im Ruhezustand kurz aufblitzen.
    static let quirks: [Face] = {
        var grin = Face()
        grin.mouthW = 205; grin.cornerL = -28; grin.cornerR = -28; grin.lipBottom = 135; grin.browY = -12
        var curious = Face()
        curious.browRaiseR = -32; curious.eyeScale = 1.05
        curious.mouthW = 70; curious.cornerL = 0; curious.cornerR = 0; curious.lipTop = -20; curious.lipBottom = 30; curious.tongue = 0
        var content = Face()
        content.squint = 1; content.mouthW = 180; content.cornerL = -24; content.cornerR = -24; content.lipBottom = 70
        var smirk = Face()
        smirk.eyeOpen = 0.8; smirk.mouthW = 150; smirk.cornerL = 4; smirk.cornerR = -26; smirk.lipTop = 2; smirk.lipBottom = 20; smirk.tongue = 0
        var hmm = Face()
        hmm.browTilt = -6; hmm.lookX = 0.6; hmm.lookY = -0.3; hmm.wander = 0
        hmm.mouthW = 60; hmm.cornerL = 6; hmm.cornerR = 6; hmm.lipTop = -8; hmm.lipBottom = 10; hmm.tongue = 0
        var stare = Face()
        stare.wander = 0; stare.eyeScale = 1.07; stare.pupil = 1.1
        stare.mouthW = 140; stare.cornerL = -16; stare.cornerR = -16; stare.lipBottom = 50
        var cheeky = Face()
        cheeky.winkR = 1; cheeky.tongueOut = 0.8; cheeky.mouthW = 130; cheeky.cornerL = -10; cheeky.cornerR = -16
        cheeky.lipTop = -6; cheeky.lipBottom = 40; cheeky.tongue = 0
        return [grin, curious, content, smirk, hmm, stare, cheeky, Face.shy]
    }()

    static let annoyed: Face = {
        var f = Face()
        f.eyeOpen = 0.5; f.lookX = 0.6; f.wander = 0; f.browTilt = -14; f.browY = 8
        f.mouthW = 120; f.cornerL = 6; f.cornerR = 6; f.lipTop = 0; f.lipBottom = 2; f.tongue = 0
        return f
    }()
}

private extension WabbelView.Mood {
    func face(_ variant: Int) -> Face {
        var f = Face()
        switch self {
        case .idle:
            break
        case .cheer:
            f.squint = 1; f.browY = -30; f.wander = 0
            f.mouthW = 230; f.cornerL = -30; f.cornerR = -30; f.lipTop = -4; f.lipBottom = 175
        case .laugh:
            f.squint = 1; f.browY = -18; f.browTilt = 8; f.wander = 0
            f.mouthW = 250; f.cornerL = -22; f.cornerR = -22; f.lipTop = 0; f.lipBottom = 200
        case .shock:
            f.eyeScale = 1.14; f.pupil = 0.5; f.browY = -38; f.wander = 0.15
            f.mouthW = 95; f.cornerL = 0; f.cornerR = 0; f.lipTop = -70; f.lipBottom = 85; f.tongue = 0.4
        case .sad:
            f.eyeOpen = 0.92; f.lookY = 0.7; f.wander = 0.3; f.browY = -14; f.browTilt = 26
            f.mouthW = 120; f.cornerL = 24; f.cornerR = 24; f.lipTop = -8; f.lipBottom = -4; f.tongue = 0
        case .smug:
            f.eyeOpen = 0.55; f.lookX = 0.45; f.wander = 0.3; f.browRaiseR = -30
            f.mouthW = 150; f.cornerL = 6; f.cornerR = -28; f.lipTop = 2; f.lipBottom = 14; f.tongue = 0
        case .explode:
            f.eyeScale = 1.22; f.pupil = 0.42; f.browY = -45; f.wander = 0
            f.mouthW = 110; f.cornerL = 0; f.cornerR = 0; f.lipTop = -80; f.lipBottom = 95; f.tongue = 0.3
        case .present:
            f.browY = -25; f.wander = 0.3
            f.mouthW = 210; f.cornerL = -28; f.cornerR = -28; f.lipTop = -4; f.lipBottom = 150
        case .drumroll:
            f.eyeScale = 1.05; f.lookY = -0.6; f.wander = 0; f.browY = -30
            f.mouthW = 70; f.cornerL = 0; f.cornerR = 0; f.lipTop = -26; f.lipBottom = 36; f.tongue = 0
        case .nervous:
            f.eyeScale = 1.08; f.pupil = 0.65; f.browTilt = 22; f.browY = -18; f.wander = 0
            f.mouthW = 180; f.cornerL = 6; f.cornerR = 6; f.lipTop = -18; f.lipBottom = 36; f.tongue = 0
            f.teeth = 1; f.sweat = 1
        case .sleep:
            f.eyeOpen = 0; f.wander = 0; f.browY = 6
            f.mouthW = 60; f.cornerL = 0; f.cornerR = 0; f.lipTop = -18; f.lipBottom = 22; f.tongue = 0
        case .kick:
            f.eyeOpen = 0.8; f.browTilt = -18; f.browY = 10; f.wander = 0; f.lookX = 0.6
            f.mouthW = 190; f.cornerL = -24; f.cornerR = -24; f.lipTop = -6; f.lipBottom = 50; f.teeth = 1; f.tongue = 0
        case .wave:
            f.browY = -15
            f.mouthW = 190; f.cornerL = -26; f.cornerR = -26; f.lipTop = -2; f.lipBottom = 120
        case .judge:
            f.eyeOpen = 0.7; f.browTilt = -18; f.browY = 12; f.wander = 0.4
            f.mouthW = 120; f.cornerL = 4; f.cornerR = 4; f.lipTop = 0; f.lipBottom = 4; f.tongue = 0
        case .verdict:
            f.eyeScale = 1.05; f.browTilt = -22; f.browY = 6; f.wander = 0
            f.mouthW = 160; f.cornerL = 4; f.cornerR = 4; f.lipTop = -30; f.lipBottom = 120; f.tongue = 0.6
        case .coverEyes:
            f.browY = -10; f.wander = 0
            f.mouthW = 150; f.cornerL = -20; f.cornerR = -20; f.lipTop = 0; f.lipBottom = 60        case .land:
            break
        case .shrug:
            f.eyeOpen = 0.85; f.browY = -26; f.browTilt = 10; f.wander = 0.3
            f.mouthW = 140; f.cornerL = 10; f.cornerR = -8; f.lipTop = 0; f.lipBottom = 12; f.tongue = 0
            if variant == 1 { f.mouthW = 100; f.cornerL = -8; f.cornerR = 12 }
        case .melt:
            f.eyeOpen = 0.75; f.lookY = 0.4; f.wander = 0.2; f.browY = -6; f.browTilt = 24
            f.mouthW = 150; f.cornerL = 20; f.cornerR = 20; f.lipTop = -4; f.lipBottom = 4; f.tongue = 0
        case .deflate:
            f.dizzy = 1; f.browY = -30; f.wander = 0
            f.mouthW = 70; f.cornerL = 0; f.cornerR = 0; f.lipTop = -40; f.lipBottom = 50; f.tongue = 0.4
        case .dizzy:
            f.dizzy = 1; f.browTilt = 12; f.browY = -10; f.wander = 0
            f.mouthW = 170; f.cornerL = -10; f.cornerR = 6; f.lipTop = -6; f.lipBottom = 60; f.tongue = 0; f.tongueOut = 1
        case .holdSign:
            f.browY = -25; f.wander = 0.2
            f.mouthW = 210; f.cornerL = -28; f.cornerR = -28; f.lipTop = -4; f.lipBottom = 150
        }
        guard variant > 0 else { return f }

        // Abweichungen der anderen Spielarten
        switch (self, variant) {
        case (.cheer, 1):
            f.mouthW = 150; f.cornerL = -24; f.cornerR = -24; f.lipTop = -10; f.lipBottom = 140
        case (.cheer, 3):
            f.squint = 0; f.winkR = 1; f.browY = -28; f.browRaiseR = -10
            f.mouthW = 230; f.cornerL = -32; f.cornerR = -32; f.lipBottom = 160
        case (.laugh, 1):
            f.squint = 0; f.pinch = 1; f.mouthW = 260; f.lipBottom = 210
        case (.laugh, 2):
            f.tears = 1
        case (.shock, 2):
            f.eyeScale = 1.3; f.pupil = 0.35; f.browY = -55
            f.mouthW = 60; f.lipTop = -36; f.lipBottom = 70; f.tongue = 0
        case (.sad, 1):
            f.eyeOpen = 0.55; f.lookY = 0.3; f.wander = 0; f.browY = -10; f.browTilt = 30; f.tears = 1
            f.mouthW = 150; f.cornerL = 28; f.cornerR = 28; f.lipTop = -26; f.lipBottom = 30; f.tongue = 0.3
        case (.sad, 2):
            f.eyeOpen = 0.6; f.lookY = 0.85; f.wander = 0; f.browTilt = 20
            f.mouthW = 100; f.cornerL = 14; f.cornerR = 14; f.lipTop = 0; f.lipBottom = 4
        case (.smug, 1):
            f.eyeOpen = 0.6; f.lookX = 0; f.cornerR = -34; f.mouthW = 170
        case (.present, 1):
            f.winkR = 1
        case (.present, 2):
            f.squint = 1; f.mouthW = 240; f.lipBottom = 180
        case (.drumroll, 1):
            f.eyeScale = 1.1; f.lookY = 0; f.mouthW = 190; f.cornerL = -20; f.cornerR = -20
            f.lipTop = -10; f.lipBottom = 40; f.teeth = 1
        case (.nervous, 1):
            f.teeth = 0; f.lookY = 0.2; f.mouthW = 80; f.cornerL = 12; f.cornerR = 12; f.lipTop = -6; f.lipBottom = 10
        case (.wave, 1):
            f.squint = 1; f.mouthW = 210; f.lipBottom = 150
        case (.judge, 1):
            f.eyeOpen = 0.45; f.browTilt = -24
        case (.coverEyes, 1):
            f.browTilt = 20; f.mouthW = 120; f.cornerL = 10; f.cornerR = 10; f.lipTop = -14; f.lipBottom = 30; f.teeth = 1
        default:
            break
        }
        return f
    }
}

/// Zeichnet Augen, Brauen und Mund in Vorlagen-Koordinaten.
private struct FacePainter {
    let face: Face
    let ctx: GraphicsContext
    var time: Double = 0

    private static let ink = Color(hex: 0x3A0614)
    private static let mouthInside = Color(hex: 0x4A0A1C)
    private static let tongue = Color(hex: 0xF2758F)
    private static let sclera = Color(hex: 0xF4E2E8)
    private static let ring = Color(hex: 0xB80A3C)
    private static let iris = Color(hex: 0x1C0410)
    private static let irisEdge = Color(hex: 0x5C1638)

    func draw() {
        var c = ctx
        // Das Gesicht wandert etwas mit dem Blick, dadurch wirkt es räumlich.
        c.translateBy(x: face.lookX * 10, y: face.lookY * 8)
        let p = FacePainter(face: face, ctx: c, time: time)
        if face.blush > 0.02 {
            p.cheek(CGPoint(x: Rig.eyeL.x - 50, y: Rig.mouth.y - 20))
            p.cheek(CGPoint(x: Rig.eyeR.x + 50, y: Rig.mouth.y - 20))
        }
        p.brow(Rig.browL, side: -1)
        p.brow(Rig.browR, side: 1)
        p.eye(Rig.eyeL, side: -1)
        p.eye(Rig.eyeR, side: 1)
        p.mouth()
        if face.sweat > 0.05 {
            p.drop(CGPoint(x: 890, y: 330), phase: 0, amount: face.sweat)
            p.drop(CGPoint(x: 345, y: 360), phase: 0.5, amount: face.sweat)
        }
        if face.tears > 0.05 {
            p.tears(CGPoint(x: Rig.eyeL.x - 40, y: Rig.eyeL.y + 70), phase: 0)
            p.tears(CGPoint(x: Rig.eyeR.x + 40, y: Rig.eyeR.y + 70), phase: 0.45)
        }
    }

    private func cheek(_ c: CGPoint) {
        var b = ctx
        b.opacity = min(1, face.blush)
        b.fill(Path(ellipseIn: CGRect(x: c.x - 62, y: c.y - 30, width: 124, height: 60)),
               with: .radialGradient(Gradient(colors: [Color(hex: 0xC8003A).opacity(0.55), Color(hex: 0xC8003A).opacity(0)]),
                                     center: c, startRadius: 0, endRadius: 66))
        for dx in [-28.0, 0, 28] {
            var line = Path()
            line.move(to: CGPoint(x: c.x + dx + 8, y: c.y - 14))
            line.addLine(to: CGPoint(x: c.x + dx - 8, y: c.y + 14))
            b.stroke(line, with: .color(Self.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        }
    }

    /// Tränenbäche und Tropfen, die vom Auge herunterlaufen.
    private func tears(_ at: CGPoint, phase: Double) {
        var stream = Path()
        stream.move(to: at)
        stream.addQuadCurve(to: CGPoint(x: at.x, y: at.y + 190), control: CGPoint(x: at.x + 10, y: at.y + 90))
        var s = ctx
        s.opacity = 0.55 * face.tears
        s.stroke(stream, with: .color(Color(hex: 0x9EDCFF)), style: StrokeStyle(lineWidth: 26, lineCap: .round))
        drop(at, phase: phase, amount: face.tears, period: 0.75, fall: 200)
    }

    /// Tropfen, der herunterläuft: Schweiß an der Schläfe oder eine Träne.
    private func drop(_ at: CGPoint, phase: Double, amount: Double, period: Double = 1.1, fall: Double = 150) {
        let p = (time / period + phase).truncatingRemainder(dividingBy: 1)
        let r = 24.0
        let c = CGPoint(x: at.x, y: at.y + fall * Ease.inCubic(p))
        var drop = Path()
        drop.move(to: CGPoint(x: c.x, y: c.y - r * 2.3))
        drop.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + r * 0.9, y: c.y - r * 1.1))
        drop.addArc(center: c, radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r * 2.3), control: CGPoint(x: c.x - r * 0.9, y: c.y - r * 1.1))
        var d = ctx
        d.opacity = amount * sin(p * .pi) * 1.4
        d.fill(drop, with: .color(Color(hex: 0x9EDCFF)))
        d.stroke(drop, with: .color(Color(hex: 0x3E9BD6)), lineWidth: 6)
        d.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.6)), with: .color(.white.opacity(0.9)))
    }

    private func brow(_ center: CGPoint, side: Double) {
        var path = Path()
        path.move(to: CGPoint(x: -72, y: 16))
        path.addQuadCurve(to: CGPoint(x: 72, y: 16), control: CGPoint(x: 0, y: -26))
        var b = ctx
        let lift = face.browY + (side > 0 ? face.browRaiseR : 0) - (face.eyeScale - 1) * 120
        b.translateBy(x: center.x, y: center.y + lift)
        b.rotate(by: .degrees(side * face.browTilt))
        b.stroke(path, with: .color(Self.ink), style: StrokeStyle(lineWidth: 30, lineCap: .round))
    }

    private func eye(_ c: CGPoint, side: Double) {
        let rx = 104 * face.eyeScale, ry = 108 * face.eyeScale
        let open = min(max(face.eyeOpen, 0), 1)
        let squint = min(max(max(face.squint, side > 0 ? face.winkR : 0), 0), 1)

        if face.dizzy > 0.5 {
            // Spiralaugen, die sich drehen.
            let oval = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            ctx.fill(oval, with: .color(.white))
            ctx.stroke(oval, with: .color(Self.ring.opacity(0.5)), lineWidth: 14)
            var spiral = Path()
            let turn = time * 7 * side
            for i in 0...60 {
                let a = Double(i) / 60 * 4.5 * .pi
                let r = (6 + 5.4 * a) * face.eyeScale
                let p = CGPoint(x: c.x + cos(a + turn) * r, y: c.y + sin(a + turn) * r)
                if i == 0 { spiral.move(to: p) } else { spiral.addLine(to: p) }
            }
            ctx.stroke(spiral, with: .color(Self.ink), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
            return
        }

        let pinch = min(max(face.pinch, 0), 1)
        if pinch > 0.5 {
            // > < : Spitze zeigt zur Nase
            var chevron = Path()
            chevron.move(to: CGPoint(x: c.x + side * 60, y: c.y - 50))
            chevron.addLine(to: CGPoint(x: c.x - side * 55, y: c.y + 4))
            chevron.addLine(to: CGPoint(x: c.x + side * 60, y: c.y + 56))
            ctx.stroke(chevron, with: .color(Self.ink), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
            return
        }
        if squint > 0.01 {
            var arc = Path()
            arc.move(to: CGPoint(x: c.x - 68, y: c.y + 20))
            arc.addQuadCurve(to: CGPoint(x: c.x + 68, y: c.y + 20), control: CGPoint(x: c.x, y: c.y - 62))
            var s = ctx
            s.opacity = squint
            s.stroke(arc, with: .color(Self.ink), style: StrokeStyle(lineWidth: 26, lineCap: .round))
        }
        guard squint < 0.99 else { return }
        var e = ctx
        e.opacity = 1 - squint

        if open < 0.1 {
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - rx * 0.8, y: c.y + ry * 0.1))
            lid.addQuadCurve(to: CGPoint(x: c.x + rx * 0.8, y: c.y + ry * 0.1), control: CGPoint(x: c.x, y: c.y + ry * 0.45))
            e.stroke(lid, with: .color(Self.ink), style: StrokeStyle(lineWidth: 22, lineCap: .round))
            return
        }

        let oval = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
        // Das Oberlid kommt von oben herunter.
        let lidY = c.y - ry + 2 * ry * (1 - open)
        var inside = e
        inside.clip(to: Path(CGRect(x: c.x - rx - 20, y: lidY, width: rx * 2 + 40, height: ry * 2 + 40)))
        inside.stroke(oval, with: .color(Self.ring.opacity(0.5)), lineWidth: 14)
        inside.clip(to: oval)
        inside.fill(oval, with: .linearGradient(Gradient(colors: [.white, Self.sclera]),
                                                startPoint: CGPoint(x: c.x, y: c.y - ry), endPoint: CGPoint(x: c.x, y: c.y + ry)))

        let r = 62 * face.pupil * face.eyeScale
        let ic = CGPoint(x: c.x - side * 14 + face.lookX * 40, y: c.y + 6 + face.lookY * 34)
        inside.fill(Path(ellipseIn: CGRect(x: ic.x - r, y: ic.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(Gradient(colors: [Self.iris, Self.iris, Self.irisEdge]),
                                          center: ic, startRadius: 0, endRadius: r))
        let h1 = max(10, 16 * face.pupil), h2 = max(5, 7 * face.pupil)
        inside.fill(Path(ellipseIn: CGRect(x: ic.x + r * 0.32 - h1, y: ic.y - r * 0.42 - h1, width: h1 * 2, height: h1 * 2)),
                    with: .color(.white))
        inside.fill(Path(ellipseIn: CGRect(x: ic.x - r * 0.35 - h2, y: ic.y + r * 0.35 - h2, width: h2 * 2, height: h2 * 2)),
                    with: .color(.white.opacity(0.8)))

        if open < 0.97 {
            let dy = (lidY - c.y) / ry
            let half = rx * sqrt(max(0, 1 - dy * dy))
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - half, y: lidY))
            lid.addLine(to: CGPoint(x: c.x + half, y: lidY))
            e.stroke(lid, with: .color(Self.ink), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        }
    }

    private func mouth() {
        let m = Rig.mouth, w = face.mouthW
        let left = CGPoint(x: m.x - w / 2, y: m.y + face.cornerL)
        let right = CGPoint(x: m.x + w / 2, y: m.y + face.cornerR)
        let top = m.y + face.lipTop, bottom = m.y + max(face.lipBottom, face.lipTop)
        var path = Path()
        path.move(to: left)
        path.addCurve(to: right, control1: CGPoint(x: left.x + w * 0.1, y: top), control2: CGPoint(x: right.x - w * 0.1, y: top))
        path.addCurve(to: left, control1: CGPoint(x: right.x + w * 0.02, y: bottom), control2: CGPoint(x: left.x - w * 0.02, y: bottom))
        path.closeSubpath()

        ctx.fill(path, with: .color(Self.mouthInside))
        let depth = face.lipBottom - face.lipTop
        if face.teeth > 0.5 {
            // Zusammengebissen: weiße Zahnreihen mit Fugen.
            var teeth = ctx
            teeth.clip(to: path)
            teeth.fill(path, with: .color(.white))
            let midY = m.y + 0.375 * (face.lipTop + face.lipBottom) + (face.cornerL + face.cornerR) / 4
            var lines = Path()
            lines.move(to: CGPoint(x: left.x, y: midY))
            lines.addLine(to: CGPoint(x: right.x, y: midY))
            for k in [-0.22, 0, 0.22] {
                lines.move(to: CGPoint(x: m.x + w * k, y: m.y - 200))
                lines.addLine(to: CGPoint(x: m.x + w * k, y: m.y + 200))
            }
            teeth.stroke(lines, with: .color(Self.ink.opacity(0.75)), lineWidth: 7)
        } else if depth > 30, face.tongue > 0 {
            var t = ctx
            t.clip(to: path)
            t.opacity = min(1, (depth - 30) / 40) * face.tongue
            let tw = w * 0.6, th = depth * 0.55
            let ty = m.y + 0.75 * face.lipBottom - th * 0.25
            t.fill(Path(ellipseIn: CGRect(x: m.x + 6 - tw / 2, y: ty - th / 2, width: tw, height: th)), with: .color(Self.tongue))
        }
        ctx.stroke(path, with: .color(Self.ink), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))

        if face.tongueOut > 0.05 {
            // Zunge hängt über die Unterlippe heraus.
            let tw = 78.0, th = 95 * face.tongueOut
            let top = m.y + 0.75 * max(face.lipBottom, face.lipTop) + (face.cornerL + face.cornerR) / 8 - 22
            let rect = CGRect(x: m.x + 14 - tw / 2, y: top, width: tw, height: th)
            let tongue = Path(roundedRect: rect, cornerSize: CGSize(width: tw / 2, height: min(tw / 2, th / 2)))
            ctx.fill(tongue, with: .color(Self.tongue))
            ctx.stroke(tongue, with: .color(Self.ink), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
            var groove = Path()
            groove.move(to: CGPoint(x: rect.midX, y: rect.minY + 14))
            groove.addLine(to: CGPoint(x: rect.midX, y: rect.minY + th * 0.55))
            ctx.stroke(groove, with: .color(Self.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            // Lippe über der Zunge
            var lip = Path()
            lip.move(to: CGPoint(x: rect.minX - 6, y: top + 4))
            lip.addLine(to: CGPoint(x: rect.maxX + 6, y: top + 4))
            ctx.stroke(lip, with: .color(Self.ink), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        }
    }
}

/// Das Platzen: Lichtblitz, Druckwellen, Scherben aus Wabbels echtem Körper, Tropfen,
/// Spritzer, die am Bildschirm kleben und herunterlaufen, und wegfliegende Arme und Füße.
/// Übrig bleibt eine Pfütze, in der seine Augen landen und weiter blinzeln.
private struct JellyExplosion: View {
    /// Sekunden seit dem Platzen.
    var t: Double
    var size: CGFloat
    var blink: Double
    var look: CGPoint

    static let span = 3.2

    private static let jelly = Color(hex: 0xF2124F)
    private static let jellyLight = Color(hex: 0xFF6A92)
    private static let jellyDark = Color(hex: 0xD80A40)
    private static let ink = Color(hex: 0x3A0614)

    private static let center = CGPoint(x: 626, y: 540)
    private static let gravity = 3000.0
    /// Luftwiderstand: Teile werden schnell langsamer, dann zieht die Schwerkraft.
    private static let drag = 2.2

    var body: some View {
        Canvas { ctx, canvas in
            guard t > 0 else { return }
            let u = size / Rig.canvas.width
            var c = ctx
            c.translateBy(x: (canvas.width - size) / 2, y: (canvas.height - size * Rig.canvas.height / Rig.canvas.width) / 2)
            c.scaleBy(x: u, y: u)
            c.translateBy(x: -Rig.origin.x, y: -Rig.origin.y)
            // Kurzes Beben nach dem Knall.
            c.translateBy(x: 16 * exp(-7 * t) * sin(t * 2 * .pi * 18), y: 0)

            drawPuddle(c)
            drawEyes(c)
            drawShards(c)
            drawLimbs(c)
            drawDroplets(c)
            drawFlash(c)
            drawSplats(c)
        }
        .accessibilityHidden(true)
    }

    // MARK: Bewegung

    /// Weg eines Teils mit Luftwiderstand und Schwerkraft.
    private static func flight(_ v: CGVector, _ t: Double, gravity: Double = gravity) -> CGPoint {
        let k = drag, d = (1 - exp(-k * t)) / k
        return CGPoint(x: v.dx * d, y: v.dy * d + 0.5 * gravity * t * t)
    }

    // MARK: Scherben

    private struct Shard { let path: Path; let pivot: CGPoint; let velocity: CGVector; let spin: Double }

    private static let shards: [Shard] = {
        var rng = SplitMix64(seed: 11)
        let n = 11
        var angles: [Double] = []
        for i in 0...n {
            let jitter: Double = i == 0 || i == n ? 0 : Double.random(in: -0.25...0.25, using: &rng)
            let a: Double = (Double(i) + jitter) / Double(n) * 2 * Double.pi - Double.pi / 2
            angles.append(a)
        }
        func point(_ a: Double, _ r: Double) -> CGPoint { CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r) }
        var result: [Shard] = []
        for i in 0..<n {
            let a0 = angles[i], a1 = angles[i + 1], mid = (a0 + a1) / 2
            let split = Double.random(in: 170...250, using: &rng)
            for outer in [false, true] {
                var path = Path()
                if outer {
                    path.move(to: point(a0, split))
                    path.addLine(to: point(mid, split * Double.random(in: 0.85...1.15, using: &rng)))
                    path.addLine(to: point(a1, split))
                    path.addLine(to: point(a1, 640))
                    path.addLine(to: point(a0, 640))
                } else {
                    path.move(to: center)
                    path.addLine(to: point(a0, split))
                    path.addLine(to: point(mid, split * Double.random(in: 0.85...1.15, using: &rng)))
                    path.addLine(to: point(a1, split))
                }
                path.closeSubpath()
                let speed = outer ? Double.random(in: 1500...2300, using: &rng) : Double.random(in: 900...1400, using: &rng)
                result.append(Shard(path: path,
                                    pivot: point(mid, outer ? (split + 380) / 2 : split * 0.6),
                                    velocity: CGVector(dx: cos(mid) * speed, dy: sin(mid) * speed - 700),
                                    spin: Double.random(in: -7...7, using: &rng)))
            }
        }
        return result
    }()

    private func drawShards(_ ctx: GraphicsContext) {
        let fade = 1 - Ease.segment(t, 0.8, 1.4)
        guard fade > 0 else { return }
        let image = ctx.resolve(Image("WabbelBody"))
        let shrink = 1 - 0.35 * Ease.segment(t, 0.15, 1.2)
        for s in Self.shards {
            let d = Self.flight(s.velocity, t)
            // Pudding-Wackeln: jede Scherbe schwabbelt im Flug.
            let wob = 1 + 0.18 * Ease.wobble(min(t / 0.9, 1), frequency: 3, decay: 3.5)
            var c = ctx
            c.opacity = fade
            c.translateBy(x: s.pivot.x + d.x, y: s.pivot.y + d.y)
            c.rotate(by: .radians(s.spin * (1 - exp(-1.5 * t)) / 1.5))
            c.scaleBy(x: shrink * wob, y: shrink / wob)
            c.translateBy(x: -s.pivot.x, y: -s.pivot.y)
            c.clip(to: s.path)
            c.draw(image, in: Rig.body)
        }
    }

    // MARK: Arme und Füße

    private static let limbs: [(name: String, rect: CGRect, velocity: CGVector, spin: Double)] = [
        ("WabbelArmLeft", Rig.armL, CGVector(dx: -1700, dy: -1300), -9),
        ("WabbelArmRight", Rig.armR, CGVector(dx: 1700, dy: -1200), 10),
        ("WabbelFootLeft", Rig.footL, CGVector(dx: -1100, dy: -900), -6),
        ("WabbelFootRight", Rig.footR, CGVector(dx: 1150, dy: -1000), 7),
    ]

    private func drawLimbs(_ ctx: GraphicsContext) {
        let fade = 1 - Ease.segment(t, 0.9, 1.5)
        guard fade > 0 else { return }
        for limb in Self.limbs {
            let d = Self.flight(limb.velocity, t)
            var c = ctx
            c.opacity = fade
            c.translateBy(x: limb.rect.midX + d.x, y: limb.rect.midY + d.y)
            c.rotate(by: .radians(limb.spin * (1 - exp(-1.5 * t)) / 1.5))
            c.draw(ctx.resolve(Image(limb.name)),
                   in: CGRect(x: -limb.rect.width / 2, y: -limb.rect.height / 2, width: limb.rect.width, height: limb.rect.height))
        }
    }

    // MARK: Tropfen

    private struct Drop { let velocity: CGVector; let radius: Double; let start: CGPoint }

    private static let drops: [Drop] = {
        var rng = SplitMix64(seed: 23)
        return (0..<46).map { _ in
            let a = Double.random(in: 0...(2 * .pi), using: &rng)
            let speed = Double.random(in: 1000...2800, using: &rng)
            let r = Double.random(in: 120...330, using: &rng)
            return Drop(velocity: CGVector(dx: cos(a) * speed, dy: sin(a) * speed - 600),
                        radius: Double.random(in: 9...24, using: &rng),
                        start: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.9))
        }
    }()

    private func drawDroplets(_ ctx: GraphicsContext) {
        let fade = 1 - Ease.segment(t, 0.6, 1.1)
        guard fade > 0 else { return }
        for drop in Self.drops {
            let d = Self.flight(drop.velocity, t)
            let decay = exp(-Self.drag * t)
            let vx = drop.velocity.dx * decay, vy = drop.velocity.dy * decay + Self.gravity * t
            let stretch = 1 + min(hypot(vx, vy) / 1400, 1.8)
            let r = drop.radius * (1 - 0.4 * Ease.segment(t, 0.2, 1.1))
            var c = ctx
            c.opacity = fade
            c.translateBy(x: drop.start.x + d.x, y: drop.start.y + d.y)
            c.rotate(by: .radians(atan2(vy, vx)))
            let rect = CGRect(x: -r * stretch, y: -r, width: r * stretch * 2, height: r * 2)
            c.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [Self.jellyLight, Self.jelly]),
                                                                startPoint: CGPoint(x: 0, y: -r), endPoint: CGPoint(x: 0, y: r)))
            c.fill(Path(ellipseIn: CGRect(x: -r * 0.2, y: -r * 0.65, width: r * 0.8, height: r * 0.45)), with: .color(.white.opacity(0.8)))
        }
    }

    // MARK: Blitz und Druckwellen

    private func drawFlash(_ ctx: GraphicsContext) {
        let c0 = Self.center
        if t < 0.22 {
            let p = t / 0.22
            let r = 220 + 760 * Ease.outCubic(p)
            ctx.fill(Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.95 * (1 - p)), .white.opacity(0)]),
                                           center: c0, startRadius: 0, endRadius: r))
        }
        for (delay, color) in [(0.0, Color.white), (0.08, Self.jellyLight)] {
            let p = Ease.segment(t, delay, delay + 0.5)
            guard p > 0, p < 1 else { continue }
            let r = 260 + 900 * Ease.outCubic(p)
            ctx.stroke(Path(ellipseIn: CGRect(x: c0.x - r, y: c0.y - r, width: r * 2, height: r * 2)),
                       with: .color(color.opacity(0.9 * (1 - p))), lineWidth: 46 * (1 - p) + 3)
        }
        // Funken
        let p = Ease.segment(t, 0, 0.35)
        if p > 0, p < 1 {
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi + 0.2
                let r0 = 300 + 600 * Ease.outCubic(p), r1 = r0 + 160 * (1 - p)
                var line = Path()
                line.move(to: CGPoint(x: c0.x + cos(a) * r0, y: c0.y + sin(a) * r0))
                line.addLine(to: CGPoint(x: c0.x + cos(a) * r1, y: c0.y + sin(a) * r1))
                ctx.stroke(line, with: .color(.white.opacity(1 - p)), style: StrokeStyle(lineWidth: 16 * (1 - p) + 2, lineCap: .round))
            }
        }
    }

    // MARK: Spritzer am Bildschirm

    private struct Splat { let at: CGPoint; let radius: Double; let hit: Double; let bumps: [Double]; let satellites: [CGVector] }

    private static let splats: [Splat] = {
        var rng = SplitMix64(seed: 5)
        let angles = [-2.55, -1.95, -1.2, -0.55, 0.15, 2.95, -3.0]
        return angles.map { a in
            let dist = Double.random(in: 520...820, using: &rng)
            return Splat(at: CGPoint(x: center.x + cos(a) * dist * 1.1, y: center.y + sin(a) * dist * 0.8),
                         radius: Double.random(in: 60...115, using: &rng),
                         hit: dist / 3200,
                         bumps: (0..<12).map { _ in Double.random(in: 0.78...1.25, using: &rng) },
                         satellites: (0..<3).map { _ in
                             let sa = Double.random(in: 0...(2 * .pi), using: &rng)
                             return CGVector(dx: cos(sa) * Double.random(in: 1.4...1.9, using: &rng),
                                             dy: sin(sa) * Double.random(in: 1.4...1.9, using: &rng))
                         })
        }
    }()

    private static func blob(_ center: CGPoint, _ r: Double, _ bumps: [Double], squash: Double = 1) -> Path {
        let n = bumps.count
        let pts = (0..<n).map { i -> CGPoint in
            let a = Double(i) / Double(n) * 2 * .pi
            return CGPoint(x: center.x + cos(a) * r * bumps[i], y: center.y + sin(a) * r * bumps[i] * squash)
        }
        var path = Path()
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n { path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i]) }
        path.closeSubpath()
        return path
    }

    private func drawSplats(_ ctx: GraphicsContext) {
        for s in Self.splats {
            let appear = Ease.outBack(Ease.segment(t, s.hit, s.hit + 0.16), overshoot: 2.2)
            guard appear > 0 else { continue }
            let fade = 1 - Ease.segment(t, 2.2, 3.0)
            guard fade > 0 else { continue }
            let slide = Ease.inOutCubic(Ease.segment(t, s.hit + 0.5, 3.0))
            let r = s.radius * appear
            let p = CGPoint(x: s.at.x, y: s.at.y + 110 * slide)
            var c = ctx
            c.opacity = fade * 0.95

            // Nase, die beim Herunterrutschen nach unten zieht.
            var drip = Path()
            drip.move(to: CGPoint(x: p.x + r * 0.15, y: p.y))
            drip.addLine(to: CGPoint(x: p.x + r * 0.15, y: p.y + r * (0.6 + 1.2 * slide)))
            c.stroke(drip, with: .color(Self.jelly), style: StrokeStyle(lineWidth: r * 0.32, lineCap: .round))

            let path = Self.blob(p, r, s.bumps, squash: 1 + 0.12 * slide)
            c.fill(path, with: .linearGradient(Gradient(colors: [Self.jellyLight, Self.jelly]),
                                               startPoint: CGPoint(x: p.x, y: p.y - r), endPoint: CGPoint(x: p.x, y: p.y + r)))
            c.stroke(path, with: .color(Self.jellyDark), lineWidth: 7)
            for v in s.satellites {
                let sr = r * 0.2
                c.fill(Path(ellipseIn: CGRect(x: p.x + v.dx * r - sr, y: p.y + v.dy * r - sr, width: sr * 2, height: sr * 2)),
                       with: .color(Self.jelly))
            }
            c.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.5, y: p.y - r * 0.6, width: r * 0.55, height: r * 0.3)),
                   with: .color(.white.opacity(0.75)))
            c.fill(Path(ellipseIn: CGRect(x: p.x + r * 0.25, y: p.y + r * 0.3, width: r * 0.14, height: r * 0.14)),
                   with: .color(.white.opacity(0.6)))
        }
    }

    // MARK: Pfütze und Augen

    private static let puddleBumps: [Double] = {
        var rng = SplitMix64(seed: 3)
        return (0..<14).map { _ in Double.random(in: 0.9...1.1, using: &rng) }
    }()

    private func drawPuddle(_ ctx: GraphicsContext) {
        let grow = Ease.outBack(Ease.segment(t, 0.3, 0.95), overshoot: 1.4)
        guard grow > 0 else { return }
        let wob = 0.035 * sin(t * 5.5) * exp(-0.4 * max(t - 1, 0))
        let rx = 380 * grow * (1 + wob), ry = 92 * grow * (1 - wob)
        let c0 = CGPoint(x: 626, y: 1068)
        var path = Path()
        let n = Self.puddleBumps.count
        let pts = (0..<n).map { i -> CGPoint in
            let a = Double(i) / Double(n) * 2 * .pi
            return CGPoint(x: c0.x + cos(a) * rx * Self.puddleBumps[i], y: c0.y + sin(a) * ry * Self.puddleBumps[i])
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(pts[n - 1], pts[0]))
        for i in 0..<n { path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i]) }
        path.closeSubpath()

        ctx.fill(Path(ellipseIn: CGRect(x: c0.x - rx * 1.05, y: c0.y - ry * 0.4, width: rx * 2.1, height: ry * 1.8)),
                 with: .color(.black.opacity(0.12 * grow)))
        ctx.fill(path, with: .linearGradient(Gradient(colors: [Self.jellyLight, Self.jelly, Self.jellyDark]),
                                             startPoint: CGPoint(x: c0.x, y: c0.y - ry), endPoint: CGPoint(x: c0.x, y: c0.y + ry)))
        ctx.stroke(path, with: .color(Self.jellyDark), lineWidth: 8)
        ctx.fill(Path(ellipseIn: CGRect(x: c0.x - rx * 0.7, y: c0.y - ry * 0.55, width: rx * 0.5, height: ry * 0.32)),
                 with: .color(.white.opacity(0.7)))
        ctx.fill(Path(ellipseIn: CGRect(x: c0.x + rx * 0.45, y: c0.y - ry * 0.35, width: rx * 0.12, height: ry * 0.18)),
                 with: .color(.white.opacity(0.6)))
        // Kleine Pfützchen daneben
        for (dx, r) in [(-1.25, 0.12), (1.22, 0.09), (1.38, 0.05)] {
            let pr = rx * r
            ctx.fill(Path(ellipseIn: CGRect(x: c0.x + rx * dx - pr, y: c0.y + ry * 0.2 - pr * 0.35, width: pr * 2, height: pr * 0.7)),
                     with: .color(Self.jelly))
        }
    }

    /// Hüpfen auf einem Boden: liefert die Höhe und ob das Teil schon zur Ruhe gekommen ist.
    private static func bounce(y0: Double, vy: Double, floor: Double, restitution: Double, t: Double) -> (y: Double, landed: Double?) {
        var y = y0, v = vy, time = t, elapsed = 0.0
        var firstLanding: Double?
        for _ in 0..<5 {
            let a = 0.5 * gravity
            let disc = v * v - 4 * a * (y - floor)
            let tau = (-v + sqrt(max(disc, 0))) / (2 * a)
            if time < tau { return (y + v * time + a * time * time, firstLanding.map { t - $0 }) }
            time -= tau; elapsed += tau
            if firstLanding == nil { firstLanding = elapsed }
            y = floor
            v = -(v + gravity * tau) * restitution
            if abs(v) < 150 { break }
        }
        return (floor, firstLanding.map { t - $0 })
    }

    private func drawEyes(_ ctx: GraphicsContext) {
        let eyes: [(start: CGPoint, end: Double, vy: Double, side: Double)] = [
            (Rig.eyeL, 548, -1550, -1), (Rig.eyeR, 706, -1400, 1),
        ]
        for eye in eyes {
            let k = 1.6
            let x = eye.start.x + (eye.end - eye.start.x) * (1 - exp(-k * t))
            let fall = Self.bounce(y0: eye.start.y, vy: eye.vy, floor: 1000, restitution: 0.4, t: t)
            let r = 104 - 26 * Ease.outCubic(Ease.segment(t, 0, 0.8))
            // Aufprall drückt das Auge kurz platt.
            let squash = fall.landed.map { 1 - 0.22 * max(0, Ease.wobble(min($0 / 0.5, 1), frequency: 2, decay: 5)) } ?? 1
            // Im Flug drehen sich die Pupillen schwindelig, danach schaut Wabbel wieder normal.
            let settle = Ease.segment(t, 1.4, 1.9)
            let spin = t * 16 + eye.side
            let dizzy = CGPoint(x: cos(spin) * 0.6, y: sin(spin) * 0.6)
            let gaze = CGPoint(x: dizzy.x + (look.x * 0.8 - dizzy.x) * settle, y: dizzy.y + (look.y * 0.6 - dizzy.y) * settle)
            let open = 1 - min(1, 1.6 * blink * settle)

            var c = ctx
            c.translateBy(x: x, y: fall.y + r)
            c.scaleBy(x: 1 / squash, y: squash)
            c.translateBy(x: 0, y: -r)
            if fall.landed != nil { c.clip(to: Path(CGRect(x: -r - 20, y: -r - 20, width: r * 2 + 40, height: r * 2 + 10))) }
            Self.eyeball(c, radius: r, gaze: gaze, open: open)
        }
    }

    private static func eyeball(_ ctx: GraphicsContext, radius r: Double, gaze: CGPoint, open: Double) {
        let oval = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        ctx.fill(Path(ellipseIn: CGRect(x: -r * 0.8, y: r * 0.75, width: r * 1.6, height: r * 0.4)), with: .color(.black.opacity(0.12)))
        if open < 0.1 {
            ctx.fill(oval, with: .color(jelly))
            var lid = Path()
            lid.move(to: CGPoint(x: -r * 0.75, y: 0))
            lid.addQuadCurve(to: CGPoint(x: r * 0.75, y: 0), control: CGPoint(x: 0, y: r * 0.4))
            ctx.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: r * 0.18, lineCap: .round))
            ctx.stroke(oval, with: .color(jellyDark), lineWidth: r * 0.08)
            return
        }
        var inside = ctx
        inside.clip(to: oval)
        inside.fill(oval, with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xF4E2E8)]),
                                                center: CGPoint(x: -r * 0.3, y: -r * 0.3), startRadius: 0, endRadius: r * 1.5))
        let ir = r * 0.58
        let ic = CGPoint(x: gaze.x * r * 0.38, y: gaze.y * r * 0.38)
        inside.fill(Path(ellipseIn: CGRect(x: ic.x - ir, y: ic.y - ir, width: ir * 2, height: ir * 2)),
                    with: .radialGradient(Gradient(colors: [Color(hex: 0x1C0410), Color(hex: 0x1C0410), Color(hex: 0x5C1638)]),
                                          center: ic, startRadius: 0, endRadius: ir))
        let h = ir * 0.28
        inside.fill(Path(ellipseIn: CGRect(x: ic.x + ir * 0.3 - h, y: ic.y - ir * 0.42 - h, width: h * 2, height: h * 2)), with: .color(.white))
        // Oberlid beim Blinzeln
        let lidY = -r + 2 * r * (1 - open)
        if open < 0.97 {
            inside.fill(Path(CGRect(x: -r, y: -r, width: r * 2, height: lidY + r)), with: .color(jelly))
            var lid = Path()
            lid.move(to: CGPoint(x: -r, y: lidY))
            lid.addLine(to: CGPoint(x: r, y: lidY))
            inside.stroke(lid, with: .color(ink), lineWidth: r * 0.12)
        }
        ctx.stroke(oval, with: .color(jellyDark), lineWidth: r * 0.08)
    }
}

// MARK: - Übergang

/// Wabbel als Vorhang: Er springt riesig von links ins Bild, verdeckt kurz alles und hüpft rechts wieder raus.
struct WabbelCurtain: View {
    /// Sekunden seit Beginn.
    var t: Double

    /// Ab hier ist der Screen ganz verdeckt und darf wechseln.
    static let coverTime = 0.36
    static let duration = 0.95

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let enter = Ease.inOutCubic(Ease.segment(t, 0, Self.coverTime))
            let leave = Ease.inCubic(Ease.segment(t, Self.coverTime + 0.14, Self.duration))
            let x = -1.9 * w * (1 - enter) + 1.9 * w * leave
            let hop = -h * 0.07 * (sin(enter * .pi) + sin(leave * .pi))
            let landing = Ease.wobble(Ease.segment(t, Self.coverTime, Self.coverTime + 0.6), frequency: 2.5, decay: 4)
            let bw = w * 1.75, bh = h * 1.4
            ZStack {
                Image("WabbelBody").resizable()
                Canvas { ctx, size in
                    let k = w * 0.75 / 520
                    ctx.translateBy(x: size.width / 2 - Rig.faceCenter.x * k, y: size.height / 2 - Rig.faceCenter.y * k)
                    ctx.scaleBy(x: k, y: k)
                    var face = WabbelView.Mood.present.face(0)
                    face.lookX = leave > 0 ? 0.8 : -0.3
                    face.wander = 0
                    FacePainter(face: face, ctx: ctx, time: t).draw()
                }
            }
            .frame(width: bw, height: bh)
            .scaleEffect(x: 1 + 0.07 * landing, y: 1 - 0.07 * landing)
            .rotationEffect(.degrees(-7 * (1 - enter) + 7 * leave))
            .position(x: w / 2 + x, y: h / 2 + hop)
        }
        .ignoresSafeArea()
        .allowsHitTesting(t < Self.duration)
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Alle Ausdrücke nebeneinander. In der App mit dem Startargument `-demo wabbel`.
/// Das Platzen läuft unten in Dauerschleife, Antippen startet es neu.
struct WabbelGallery: View {
    @State private var exploding = false
    @State private var round = 0

    var body: some View {
        ScrollView {
            HStack(spacing: 6) {
                ForEach(Q.playerColors.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        WabbelView(mood: .idle, size: 44, playerColor: i)
                        Circle().fill(Q.playerColors[i]).frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.top, 60)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ForEach(WabbelView.Mood.allCases.filter { $0 != .explode }, id: \.self) { mood in
                    VStack {
                        WabbelView(mood: mood, size: 95)
                        Text(String(describing: mood)).font(.caption)
                    }
                }
            }
            .padding(30)

            WabbelView(mood: exploding ? .explode : .idle, size: 150)
                .padding(.vertical, 90)
                .onTapGesture { round += 1 }
        }
        .background(Color(hex: 0xFFF1E0))
        .task(id: round) {
            while !Task.isCancelled {
                exploding = false
                try? await Task.sleep(for: .seconds(1))
                exploding = true
                try? await Task.sleep(for: .seconds(4.5))
            }
        }
    }
}

#Preview("Ausdrücke") { WabbelGallery() }
#endif
