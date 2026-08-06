import SwiftUI

/// One grid button on the felt opens this. Everything that is not the table lives here.
struct HubScreen: View {
    @ObservedObject var game: BlackjackGame
    @ObservedObject var gameRoom: GameRoomStore
    @ObservedObject var profile: ProfileStore
    let lighting: AmbientLighting
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Where to?")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .kerning(-0.8)
                    .foregroundStyle(theme.textDark)

                Spacer(minLength: 8)

                GlassIconButton(
                    systemImage: "xmark",
                    size: 40,
                    tint: theme.glassTint,
                    accessibilityText: "Back to the table",
                    action: { screen = .table }
                )
            }

            VStack(spacing: 12) {
                DestinationRow(
                    title: "Tables",
                    subtitle: "\(game.preset.name) · \(game.preset.limitsLabel) · \(game.preset.shoeLabel)",
                    systemImage: "table.furniture.fill",
                    background: theme.accentTint,
                    action: { screen = .floors }
                )

                DestinationRow(
                    title: "Game Room",
                    subtitle: gameRoom.hasUndiscoveredItems
                        ? "Something new on the shelf"
                        : "Things you have found, where you left them",
                    systemImage: "chair.lounge.fill",
                    showsGlow: gameRoom.hasUndiscoveredItems,
                    action: { screen = .gameRoom }
                )

                DestinationRow(
                    title: "Play together",
                    subtitle: "Up to four, one dealer, six-letter code",
                    systemImage: "person.3.fill",
                    action: { screen = .multiplayerLobby }
                )

                DestinationRow(
                    title: "Fractured",
                    subtitle: TablePreset.fractured.tagline,
                    systemImage: "circle.hexagongrid.fill",
                    iconColor: Color(hex: 0x6E5DAE),
                    background: Color(hex: 0x8E7DC6, opacity: 0.16),
                    action: { screen = .fracturedLobby }
                )

                DestinationRow(
                    title: profile.name,
                    subtitle: "Your card, your code, what you have equipped",
                    systemImage: "person.crop.circle.fill",
                    action: { screen = .profile }
                )

                DestinationRow(
                    title: "Settings",
                    subtitle: nil,
                    systemImage: "gearshape.fill",
                    action: { screen = .settings }
                )
            }
            .padding(.top, 22)

            Spacer(minLength: 12)

            // §10.3 — the only place the app mentions that the light is moving.
            HStack(spacing: 8) {
                Image(systemName: lighting.iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(lighting.label) · the glass follows your clock")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(theme.textMid)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}
