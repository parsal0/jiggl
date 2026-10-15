import SwiftUI

/// App-Icon: Wabbel groß auf Blau, der Farbe der Startseite.
struct AppIconArt: View {
    static let size: CGFloat = 1024

    var body: some View {
        ZStack {
            Q.launch
            // Weicher Lichtfleck hinter Wabbel, damit er nach vorn kommt.
            RadialGradient(colors: [.white.opacity(0.22), .white.opacity(0)], center: .center, startRadius: 0, endRadius: 460)
                .offset(y: -40)
            WabbelView(mood: .idle, size: 700, animated: false)
                .offset(y: 30)
        }
        .frame(width: Self.size, height: Self.size)
    }
}

#if DEBUG
/// Markenübersicht mit `-demo brand`. Legt das App-Icon als PNG in „Documents“ ab und schreibt den Pfad ins Log.
struct BrandGallery: View {
    @State private var exported: String?

    var body: some View {
        ZStack {
            Q.launch.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 36) {
                    JigglLogo(size: 90, popIn: true)
                    JigglLogo(size: 48)
                    JigglBadge(size: 24)
                    AppIconArt()
                        .scaleEffect(0.2)
                        .frame(width: 205, height: 205)
                        .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                    ForEach([Q.pink, Q.orange, Q.green, Q.purple, Q.yellow], id: \.self) { color in
                        JigglLogo(size: 36, fill: color == Q.pink ? Q.ink : Q.brand)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(color)
                    }
                    if let exported { Text(exported).font(.qBody(11)).foregroundStyle(.white) }
                }
                .padding(.vertical, 40)
            }
        }
        .task { export() }
    }

    private func export() {
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        renderer.isOpaque = true
        guard let data = renderer.uiImage?.pngData(),
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("AppIcon.png")
        try? data.write(to: url)
        exported = url.path
        print("ICON_EXPORT \(url.path)")
    }
}
#endif
