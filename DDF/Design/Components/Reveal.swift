import SwiftUI

/// Kreis, der von `origin` aus wächst, bis er den ganzen Screen bedeckt.
/// Der Kreis darf über den eigenen Rahmen hinausgehen, so werden auch die Ränder hinter Notch und Home-Leiste mit aufgedeckt.
struct RevealShape: Shape {
    var progress: CGFloat
    var origin: UnitPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.minX + rect.width * origin.x, y: rect.minY + rect.height * origin.y)
        // Weitester Punkt plus Rand für die Bereiche außerhalb der Safe Area.
        let reach = hypot(max(center.x, rect.width - center.x), max(center.y, rect.height - center.y)) + 160
        let r = max(0, reach * progress)
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
}

private struct RevealModifier: ViewModifier {
    var progress: CGFloat
    var origin: UnitPoint

    func body(content: Content) -> some View {
        content.clipShape(RevealShape(progress: progress, origin: origin))
    }
}

/// Alter Screen rückt ein Stück nach hinten, während der neue drüber aufgeht.
private struct RecedeModifier: ViewModifier {
    var amount: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - 0.06 * amount)
            .brightness(-0.12 * amount)
    }
}

extension AnyTransition {
    /// Neuer Screen geht als Farbkreis auf, z. B. von dem Knopf aus, der ihn geöffnet hat.
    /// Mit „Bewegung reduzieren“ nur eine Überblendung.
    static func reveal(from origin: UnitPoint, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: RevealModifier(progress: 0, origin: origin),
                                 identity: RevealModifier(progress: 1, origin: origin)),
            removal: .modifier(active: RecedeModifier(amount: 1), identity: RecedeModifier(amount: 0))
        )
    }
}
