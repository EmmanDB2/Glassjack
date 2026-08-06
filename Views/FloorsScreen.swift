import SwiftUI

/// The table picker. Rules and looks both come from whichever floor you sit at.
struct FloorsScreen: View {
    @ObservedObject var game: BlackjackGame
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Tables", onBack: { screen = .hub })

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(TablePreset.floors) { floor in
                        FloorCard(
                            floor: floor,
                            isUnlocked: game.isUnlocked(floor),
                            isSeated: floor.id == game.preset.id,
                            canSwitch: game.canChangeFloor,
                            onPick: {
                                game.enter(floor)
                                screen = .table
                            }
                        )
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
            }

            Text("Rules and looks both come from the table you pick.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }
}

private struct FloorCard: View {
    @Environment(\.theme) private var theme

    let floor: TablePreset
    let isUnlocked: Bool
    let isSeated: Bool
    let canSwitch: Bool
    let onPick: () -> Void

    var body: some View {
        if isUnlocked {
            Button {
                FeedbackManager.buttonPress()
                onPick()
            } label: {
                unlockedBody
            }
            .buttonStyle(.plain)
            .disabled(isSeated || !canSwitch)
            .opacity(canSwitch || isSeated ? 1 : 0.55)
        } else {
            lockedBody
        }
    }

    // MARK: Unlocked

    private var unlockedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(floor.name)
                    .font(.system(size: 20, weight: .black, design: floor.theme.usesDarkChrome ? .serif : .rounded))
                    .foregroundStyle(ink)

                if isSeated {
                    Text("PLAYING")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: 0x00695F))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.7)))
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 18) {
                Stat(title: "Limits", value: floor.limitsLabel, ink: ink, muted: mutedInk)
                if floor.rules.entryFee > 0 {
                    Stat(title: "Entry", value: floor.rules.entryFee.money, ink: ink, muted: mutedInk)
                } else {
                    Stat(title: "Blackjack", value: floor.blackjackLabel, ink: ink, muted: mutedInk)
                }
                Stat(title: "Shoe", value: floor.shoeLabel, ink: ink, muted: mutedInk)
                Spacer(minLength: 0)
            }

            Text(floor.theme.usesDarkChrome ? floor.tagline : floor.rulesLine)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(mutedInk)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: isSeated ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(floor.theme.usesDarkChrome ? 0.20 : 0.07), radius: 16, y: 5)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if floor.theme.usesDarkChrome {
            ZStack {
                LinearGradient(
                    colors: [floor.theme.tableFeltColor, floor.theme.shellBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [floor.theme.primaryColor.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.9, y: -0.1),
                    startRadius: 0,
                    endRadius: 220
                )
            }
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isSeated ? floor.theme.accentTint : theme.glassTint)
        }
    }

    private var ink: Color {
        floor.theme.usesDarkChrome ? floor.theme.textDark : theme.textDark
    }

    private var mutedInk: Color {
        floor.theme.usesDarkChrome ? floor.theme.textMid : theme.textMid
    }

    private var borderColor: Color {
        if floor.theme.usesDarkChrome {
            return floor.theme.primaryColor.opacity(0.45)
        }
        return isSeated ? floor.theme.accentColor.opacity(0.55) : theme.hairline
    }

    // MARK: Locked

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(floor.name)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.textMid)

            Text(floor.unlock.caption)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textMid)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.glassTint.opacity(0.6))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(floor.name), locked. \(floor.unlock.caption)")
    }
}

private struct Stat: View {
    let title: String
    let value: String
    let ink: Color
    let muted: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
        }
    }
}
