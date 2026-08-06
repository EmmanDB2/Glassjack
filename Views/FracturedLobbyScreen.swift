import SwiftUI

/// §8 — the pre-session lobby. Same cozy layout as the rest of the app with mint
/// swapped for violet: this reads as a different table, not a different game.
struct FracturedLobbyScreen: View {
    @ObservedObject var game: BlackjackGame
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    private let violet = Color(hex: 0x8E7DC6)
    private let deepViolet = Color(hex: 0x6E5DAE)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(
                title: "Fractured",
                subtitle: "A session stack of \(TablePreset.fractured.rules.sessionStack.money). Nothing here touches your balance.",
                onBack: { screen = .hub }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    challengeSection
                    modifierSection
                    wildCardSection
                }
                .padding(.top, 22)
                .padding(.bottom, 16)
            }

            // The one solid button in the app. Entering a bent-rules table should
            // feel like a decision, so it does not hide behind glass.
            Button {
                FeedbackManager.buttonPress()
                game.enterFractured()
                screen = .table
            } label: {
                Text("Enter Fractured")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [violet, deepViolet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
            .shadow(color: deepViolet.opacity(0.35), radius: 14, y: 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: Challenge

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: "Challenge")

            Button {
                FeedbackManager.buttonPress()
                cycleChallenge()
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.fracturedChallenge?.title ?? "No challenge")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textDark)
                        .multilineTextAlignment(.leading)

                    Text(game.fracturedChallenge?.detail ?? "Play as long as the stack lasts.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(Color(hex: 0x8E7DC6, opacity: 0.18), cornerRadius: 22, interactive: true)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap to choose a different challenge")
        }
    }

    private func cycleChallenge() {
        let all = ChallengeScenario.catalog
        guard let current = game.fracturedChallenge,
              let index = all.firstIndex(of: current) else {
            game.fracturedChallenge = all.first
            return
        }
        // Walks the list and then off the end, which means "no challenge".
        game.fracturedChallenge = index + 1 < all.count ? all[index + 1] : nil
    }

    // MARK: Modifiers

    private var modifierSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: "Modifiers")

            ForEach(Array(game.fracturedModifiers.enumerated()), id: \.element.id) { index, modifier in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(modifier.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textDark)
                        Text(modifier.detail)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textMid)
                    }

                    Spacer(minLength: 8)

                    Toggle("", isOn: Binding(
                        get: { game.fracturedModifiers[index].isEnabled },
                        set: { game.fracturedModifiers[index].isEnabled = $0 }
                    ))
                    .labelsHidden()
                    .tint(violet)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassSurface(theme.glassTint, cornerRadius: 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(modifier.name). \(modifier.detail)")
            }
        }
    }

    // MARK: Wild cards

    private var wildCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("WILD CARDS IN THE SHOE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1.1)
                    .foregroundStyle(theme.textMid)

                Spacer(minLength: 8)

                Text("\(game.fracturedWildCardCount)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(game.fracturedWildCardCount) },
                    set: { game.fracturedWildCardCount = Int($0.rounded()) }
                ),
                in: 0...Double(game.maxFracturedWildCards),
                step: 1
            )
            .tint(violet)
            .accessibilityLabel("Wild cards in the shoe")
            .accessibilityValue("\(game.fracturedWildCardCount)")
        }
    }
}
