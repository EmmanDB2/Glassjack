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
                    supporterCard
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

    // MARK: Supporter pack

    /// §9 — cosmetics only. Nothing behind this ever touches play.
    private var supporterCard: some View {
        Button {
            FeedbackManager.buttonPress()
            settings.grantSupporterPack()
            game.say("Thank you — the supporter cosmetics are yours", icon: "heart.fill")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: settings.hasSupporterPack ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.primaryColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.hasSupporterPack ? "Thank you" : "Support Glassjack")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textDark)

                    Text(settings.hasSupporterPack
                         ? "Supporter cosmetics unlocked"
                         : "$2.99 once · cosmetics only, never an edge")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                }

                Spacer(minLength: 0)

                if !settings.hasSupporterPack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textMid)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(theme.accentTint.opacity(0.55), cornerRadius: 22, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(settings.hasSupporterPack)
    }
}

private struct SettingToggle: View {
    @Environment(\.theme) private var theme

    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textDark)

                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(theme.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(theme.glassTint, cornerRadius: 18)
    }
}
