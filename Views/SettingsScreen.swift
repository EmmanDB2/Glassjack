import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var game: BlackjackGame
    @ObservedObject var settings: SettingsStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "Settings", onBack: { screen = .hub })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    feelSection
                    performanceSection
                    bankrollSection
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: Feel

    private var feelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Feel")

            SettingToggle(title: "Haptics", isOn: $settings.hapticsEnabled)
            SettingToggle(title: "Ambient music", isOn: $settings.ambientMusicEnabled)
            SettingToggle(
                title: "Follow the clock",
                detail: "Light warms up as the day goes on",
                isOn: $settings.followsClock
            )
        }
    }

    // MARK: Performance

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Performance")

            SettingToggle(
                title: "Full glass blur",
                detail: reduceTransparency
                    ? "Overridden while Reduce Transparency is on"
                    : "Off on older devices to keep things cool",
                isOn: $settings.fullGlassBlur
            )
            .disabled(reduceTransparency)
            .opacity(reduceTransparency ? 0.6 : 1)
        }
    }

    // MARK: Bankroll

    private var bankrollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Bankroll")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Balance")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textDark)

                    Spacer(minLength: 8)

                    Text(game.player.balance.money)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.textDark)
                        .contentTransition(.numericText())
                }

                Text("At zero, \(game.rules.bankruptGrantAmount.money) quietly arrives every \(game.rules.bankruptGrantIntervalMinutes) minutes.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(theme.glassTint, cornerRadius: 18)

            Button {
                FeedbackManager.buttonPress()
                game.resetBankroll()
                screen = .table
            } label: {
                Text("Reset to \(game.rules.startingBalance.money)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(theme.glassTint, cornerRadius: 18, interactive: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

}
