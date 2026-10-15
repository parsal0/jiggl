import Foundation

/// Kurven für zeitgesteuerte Sequenzen (After-Effects-Stil, ohne Spring-Unschärfe).
enum Ease {
    /// Fortschritt 0…1 eines Abschnitts von `start` bis `end` Sekunden.
    static func segment(_ t: Double, _ start: Double, _ end: Double) -> Double {
        min(max((t - start) / (end - start), 0), 1)
    }

    static func outCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func inCubic(_ x: Double) -> Double { x * x * x }
    static func inOutCubic(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

    /// Schießt über das Ziel hinaus und federt zurück.
    static func outBack(_ x: Double, overshoot s: Double = 1.9) -> Double {
        let c3 = s + 1
        return 1 + c3 * pow(x - 1, 3) + s * pow(x - 1, 2)
    }

    /// Gedämpfte Schwingung, z. B. für Wackler nach einem Aufprall.
    static func wobble(_ x: Double, frequency: Double = 3, decay: Double = 4) -> Double {
        guard x > 0 else { return 0 }
        return sin(x * .pi * 2 * frequency) * exp(-decay * x)
    }
}
