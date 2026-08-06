import SwiftUI

/// What just happened, without a harsh red flash anywhere in sight — §5.
struct RoundSummaryScreen: View {
    @ObservedObject var game: BlackjackGame
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    private var summary: RoundSummary? { game.lastSummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Round")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .kerning(-0.7)
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

            resultCard
                .padding(.top, 24)

            statRow
                .padding(.top, 16)

            if let discovery = summary?.discovery {
                DiscoveryCard(item: discovery)
                    .padding(.top, 16)
            }

            Spacer(minLength: 16)

            HStack(spacing: 12) {
                PrimaryAction(title: "Game Room", height: 52) {
                    screen = .gameRoom
                }

                PrimaryAction(title: game.rebetLabel, tint: theme.accentTint, height: 52) {
                    game.rebetLastAmount()
                    screen = .table
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text(resultWord.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .kerning(1.3)
                .foregroundStyle(theme.textMid)

            Text(resultAmount)
                .font(.system(size: 46, weight: .black, design: .rounded))
                .kerning(-1.2)
                .monospacedDigit()
                .foregroundStyle(resultColor)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(summary?.detail ?? "No hand played yet")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassSurface(theme.glassTint, cornerRadius: 28)
        .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatTile(title: "Hands", value: "\(game.handsThisSession)", ink: theme.textDark)
            StatTile(
                title: "Session",
                value: game.sessionNet.signedMoney,
                ink: game.sessionNet >= 0 ? Color(hex: 0x1E7A36) : theme.textDark
            )
            StatTile(title: "Shoe", value: game.shoeCountLabel, ink: theme.textDark)
        }
    }

    private var resultWord: String {
        guard let summary else { return "Nothing yet" }
        switch summary.outcome {
        case .blackjack: return "Blackjack"
        case .win: return "You win"
        case .push: return "Push"
        case .bust: return "Bust"
        case .loss: return "Dealer takes it"
        }
    }

    private var resultAmount: String {
        guard let summary else { return "—" }
        return summary.net == 0 ? "Even" : summary.net.signedMoney
    }

    private var resultColor: Color {
        guard let summary, summary.net > 0 else { return theme.textDark }
        return Color(hex: 0x1E7A36)
    }
}

private struct StatTile: View {
    @Environment(\.theme) private var theme

    let title: String
    let value: String
    let ink: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(0.7)
                .foregroundStyle(theme.textMid)

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassSurface(theme.glassTint, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

/// §7 — the closest the game comes to announcing an unlock: a line on the summary,
/// never a popup.
private struct DiscoveryCard: View {
    @Environment(\.theme) private var theme

    let item: RoomItem

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(item.swatch)
                .frame(width: 38, height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("A new \(item.category.title.lowercased().dropLast()) is on the shelf")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)
                    .multilineTextAlignment(.leading)

                Text("\(item.name) · \(item.trigger.caption.replacingOccurrences(of: "\n", with: " "))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassSurface(theme.accentTint.opacity(0.6), cornerRadius: 22)
    }
}
