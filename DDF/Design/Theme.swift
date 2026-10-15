import SwiftUI
import CoreText
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Design-Tokens von Jiggl: kräftige Vollfarben, bunte Sticker mit weißem Rand, runde fette Schrift.
enum Q {
    // Grundtöne
    static let bg = Color(hex: 0xF4F4F1)
    static let surface = Color.white
    static let ink = Color(hex: 0x141414)
    static let muted = Color(hex: 0x141414).opacity(0.55)
    static let line = Color(hex: 0x141414).opacity(0.08)

    // Bunte Farben
    static let blue = Color(hex: 0x3D5AFE)
    static let pink = Color(hex: 0xF0377A)
    static let orange = Color(hex: 0xFF8A1F)
    static let green = Color(hex: 0x12B886)
    static let purple = Color(hex: 0x8B5CF6)
    static let sky = Color(hex: 0x1FA9F0)
    static let red = Color(hex: 0xFF4D4D)
    static let yellow = Color(hex: 0xFFC72C)
    static let lime = Color(hex: 0xCFF54B)

    // Marke: Wabbels Pink. Jedes Spiel bringt nur eine eigene Farbe und einen Titel mit.
    static let brand = pink
    /// Grund des Startbildschirms, gleich wie die Startseite, damit der Übergang nahtlos ist.
    static let launch = blue

    // Bedeutung
    static let correct = green
    static let wrong = red

    // Sticker
    static let border: CGFloat = 5
    static let radius: CGFloat = 24

    /// Spielerfarben. Gelb bekommt dunkle Schrift, alle anderen weiße.
    static let playerColors: [Color] = [blue, pink, orange, green, purple, sky, red, yellow]

    static func playerColor(_ index: Int) -> Color {
        playerColors[wrap(index, playerColors.count)]
    }

    static func onPlayerColor(_ index: Int) -> Color {
        wrap(index, playerColors.count) == 7 ? ink : .white
    }

    /// Feste Farbe pro Fragenkategorie, damit „Geografie“ immer gleich aussieht.
    static func categoryColor(_ category: String) -> Color {
        let accents = [blue, pink, orange, green, purple, sky]
        let sum = category.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return accents[sum % accents.count]
    }

    /// Timerfarbe: grün, dann orange, am Ende rot.
    static func timerColor(remainingFraction f: Double) -> Color {
        f > 0.5 ? green : (f > 0.25 ? orange : red)
    }

    private static func wrap(_ i: Int, _ n: Int) -> Int { ((i % n) + n) % n }
}

/// Schrift: Lilita One für Titel, wenn sie im Bundle liegt, sonst SF Rounded in Black. Text in SF Rounded.
enum QFont {
    static let titleFamily = "Lilita One"

    static func registerBundledFonts() {
        let urls = ["ttf", "otf"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static let hasTitleFont: Bool = {
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        return names.contains(titleFamily)
    }()

    static func title(_ size: CGFloat) -> Font {
        hasTitleFont ? .custom(titleFamily, size: size) : .system(size: size, weight: .black, design: .rounded)
    }

    /// Textschrift. Wächst mit der iPhone-Einstellung „Textgröße“ mit, aber höchstens um 30 %, damit die Layouts halten.
    /// Titel bleiben fest, sie sind ohnehin groß und sitzen oft in Stickern mit fester Größe.
    static func body(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size * bodyScale, weight: weight, design: .rounded)
    }

    /// Textschrift ohne Mitwachsen, z. B. für die Teilen-Karte, die als Bild in fester Größe gerendert wird.
    static func fixedBody(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static var bodyScale: CGFloat {
        let scale = UIFontMetrics(forTextStyle: .body).scaledValue(for: 100) / 100
        return min(max(scale, 0.9), 1.3)
    }
}

extension Font {
    /// Titelschrift.
    static func q(_ size: CGFloat) -> Font { QFont.title(size) }
    /// Textschrift.
    static func qBody(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { QFont.body(size, weight) }
    /// Textschrift in fester Größe.
    static func qBodyFixed(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { QFont.fixedBody(size, weight) }
}
