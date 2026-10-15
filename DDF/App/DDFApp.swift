import SwiftUI

@main
struct DDFApp: App {
    @State private var model: AppModel

    init() {
        QFont.registerBundledFonts()
        let model = AppModel()
        #if DEBUG
        DemoLauncher.apply(to: model)
        #endif
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                // Systemteile (Sheets, Dialoge) wachsen mit, aber nicht ins Unlesbare für das Layout.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showSplash = Self.splashOnLaunch

    private static var splashOnLaunch: Bool {
        #if DEBUG
        DemoLauncher.scene == nil || DemoLauncher.scene == "splash"
        #else
        true
        #endif
    }

    var body: some View {
        ZStack {
            #if DEBUG
            if DemoLauncher.scene == "wabbel" {
                WabbelGallery()
            } else if DemoLauncher.scene == "brand" {
                BrandGallery()
            } else if let session = model.session {
                GameView(session: session)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            } else {
                HomeView()
                    .transition(.opacity)
            }
            #else
            if let session = model.session {
                GameView(session: session)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            } else {
                HomeView()
                    .transition(.opacity)
            }
            #endif

            if showSplash {
                SplashView { withAnimation(.easeOut(duration: 0.35)) { showSplash = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.session == nil)
    }
}
