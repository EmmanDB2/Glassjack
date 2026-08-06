import SwiftUI

enum AppScreen: Hashable {
    case table
    case hub
    case floors
    case gameRoom
    case multiplayerLobby
    case multiplayerTable
    case fracturedLobby
    case summary
    case settings
    case profile
}

/// Owns the stores, composes the active theme, and swaps between the screens the
/// hub leads to. There is no navigation chrome — screens cross-fade in place.
struct RootView: View {
    @StateObject private var game = BlackjackGame()
    @StateObject private var settings = SettingsStore()
    @StateObject private var gameRoom = GameRoomStore()
    @StateObject private var session = MultiplayerSession()
    @StateObject private var profile = ProfileStore()
    @StateObject private var lighting = DynamicLightingService.shared

    @State private var screen: AppScreen = .table

    private var theme: ThemeConfig {
        var composed = game.preset.theme
            .applying(lighting.lighting)
            .withBlur(settings.fullGlassBlur)

        // A chosen felt only reads on the light floors; the dark rooms keep their own.
        if !composed.usesDarkChrome {
            composed.tableFeltColor = gameRoom.selectedFeltColor
            composed.shellBackground = gameRoom.selectedFeltColor
        }
        composed.cardBackTint = gameRoom.selectedCardBackTint
        composed.cardBackDesign = gameRoom.selectedCardBackDesign
        return composed
    }

    var body: some View {
        ZStack {
            TableBackground()

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let toast = game.toast {
                VStack(spacing: 0) {
                    ToastBanner(message: toast)
                        .padding(.horizontal, 18)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .environment(\.theme, theme)
        .environment(\.glassBlurEnabled, settings.fullGlassBlur)
        .preferredColorScheme(theme.usesDarkChrome ? .dark : .light)
        .animation(.smooth(duration: 0.26), value: screen)
        .task { start() }
        .onChange(of: settings.hapticsEnabled) { _, enabled in
            FeedbackManager.isEnabled = enabled
        }
        .onChange(of: settings.ambientMusicEnabled) { _, enabled in
            MusicManager.shared.isEnabled = enabled
        }
        .onChange(of: settings.followsClock) { _, follows in
            lighting.followsClock = follows
        }
        .onChange(of: game.ejectMessage) { _, message in
            guard let message else { return }
            game.say(message, icon: "figure.walk.departure")
            game.clearEjectMessage()
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screen {
        case .table:
            TableScreen(game: game, gameRoom: gameRoom, screen: $screen)
                .transition(fade)

        case .hub:
            HubScreen(game: game, gameRoom: gameRoom, profile: profile, lighting: lighting.lighting, screen: $screen)
                .transition(fade)

        case .floors:
            FloorsScreen(game: game, screen: $screen)
                .transition(fade)

        case .gameRoom:
            GameRoomScreen(gameRoom: gameRoom, screen: $screen)
                .transition(fade)

        case .multiplayerLobby:
            MultiplayerLobbyScreen(session: session, profile: profile, screen: $screen)
                .transition(fade)

        case .multiplayerTable:
            MultiplayerTableScreen(session: session, game: game, gameRoom: gameRoom, screen: $screen)
                .transition(fade)

        case .fracturedLobby:
            FracturedLobbyScreen(game: game, screen: $screen)
                .transition(fade)

        case .summary:
            RoundSummaryScreen(game: game, screen: $screen)
                .transition(fade)

        case .settings:
            SettingsScreen(game: game, settings: settings, screen: $screen)
                .transition(fade)

        case .profile:
            ProfileScreen(game: game, gameRoom: gameRoom, profile: profile, screen: $screen)
                .transition(fade)
        }
    }

    private var fade: AnyTransition {
        .opacity.combined(with: .offset(y: 6))
    }

    private func start() {
        game.attach(gameRoom: gameRoom, settings: settings)
        FeedbackManager.isEnabled = settings.hapticsEnabled
        MusicManager.shared.isEnabled = settings.ambientMusicEnabled
        lighting.followsClock = settings.followsClock
        lighting.refresh()
        lighting.start()
    }
}

#Preview {
    RootView()
}
