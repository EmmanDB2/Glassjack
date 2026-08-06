import SwiftUI

@main
struct GlassjackApp: App {
    init() {
        Task { @MainActor in
            SoundManager.shared.prepare()
            MusicManager.shared.prepare()
            MusicManager.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
