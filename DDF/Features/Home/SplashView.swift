import SwiftUI

/// Startbildschirm beim Öffnen der App: Wabbel plumpst herein, dann ploppt „Jiggl“ Buchstabe für Buchstabe auf.
/// Danach blendet er in die Startseite über, die dieselbe Farbe hat. Antippen überspringt.
struct SplashView: View {
    var finished: () -> Void

    @State private var start = Date()
    @State private var done = false

    private static let duration = 2.1

    var body: some View {
        ZStack {
            Q.launch.ignoresSafeArea()
            VStack(spacing: 6) {
                WabbelView(mood: .land, size: 150)
                JigglLogo(size: 84, popIn: true, popDelay: 0.45)
            }
            .offset(y: -30)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .task {
            try? await Task.sleep(for: .seconds(Self.duration))
            finish()
        }
    }

    private func finish() {
        guard !done else { return }
        done = true
        finished()
    }
}
