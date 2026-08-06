import SwiftUI

/// 3b — suit, then glass colour, then rank, with a live preview above.
///
/// Edits are held as a draft so "Save" means something; tapping the scrim backs out
/// without changing anything.
struct FavouriteCardPicker: View {
    @ObservedObject var profile: ProfileStore
    @ObservedObject var gameRoom: GameRoomStore
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    @State private var rank: Rank = .ace
    @State private var suit: Suit = .spades
    @State private var tint: CardTint = .mint

    /// A, 2…10, J, Q, K — the order a deck is read in, not the order it is scored in.
    private static let rankOrder: [Rank] = [
        .ace, .two, .three, .four, .five, .six, .seven,
        .eight, .nine, .ten, .jack, .queen, .king
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            sheet
        }
        .ignoresSafeArea()
        .onAppear {
            rank = profile.favouriteRank
            suit = profile.favouriteSuit
            tint = profile.favouriteTint
        }
    }

    private var scrim: some View {
        Color(hex: 0x14191F, opacity: 0.22)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture(perform: onClose)
            .accessibilityLabel("Close without saving")
    }

    private var sheet: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(theme.textMid.opacity(0.5))
                .frame(width: 44, height: 5)

            titleRow
            preview
            suitPicker
            glassPicker
            rankGrid
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(sheetBackground)
        .shadow(color: .black.opacity(0.18), radius: 20, y: -8)
        .transition(.move(edge: .bottom))
    }

    private var sheetBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 38,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 38,
            style: .continuous
        )
        .fill(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var titleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Favourite card")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .kerning(-0.6)
                    .foregroundStyle(theme.textDark)

                Text("Shows on your seat at every table")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }

            Spacer(minLength: 8)

            Button {
                FeedbackManager.buttonPress()
                profile.favouriteRank = rank
                profile.favouriteSuit = suit
                profile.favouriteTint = tint
                onClose()
            } label: {
                Text("Save")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .glassCapsule(theme.accentTint, interactive: true)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Preview

    private var preview: some View {
        HStack(spacing: 16) {
            PlayingCardView(card: Card(rank: rank, suit: suit), isFaceDown: false, tint: tint.cardTint)
                .frame(width: 78, height: 111)
                .rotationEffect(.degrees(-3.5))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(rank.name) of \(suit.name.lowercased()) · \(tint.name)")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(dealtLine)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(theme.glassTint, cornerRadius: 26)
        .animation(.smooth(duration: 0.25), value: rank)
        .animation(.smooth(duration: 0.25), value: suit)
        .animation(.smooth(duration: 0.25), value: tint)
    }

    private var dealtLine: String {
        let seen = gameRoom.timesSeen(Card(rank: rank, suit: suit))
        return seen == 0 ? "Not dealt to you yet" : "Dealt to you \(seen) times"
    }

    // MARK: Suit

    private var suitPicker: some View {
        HStack(spacing: 7) {
            ForEach(Suit.allCases, id: \.self) { candidate in
                Button {
                    FeedbackManager.buttonPress()
                    suit = candidate
                } label: {
                    Text(candidate.glyph)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(candidate.isRed ? Color(hex: 0xD0333B) : theme.textDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if candidate == suit {
                                Capsule()
                                    .fill(Color.white.opacity(0.95))
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.name)
            }
        }
        .padding(4)
        .glassCapsule(theme.glassTint)
        .animation(.snappy(duration: 0.22), value: suit)
    }

    // MARK: Glass

    private var glassPicker: some View {
        HStack(spacing: 10) {
            Text("Glass")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(theme.textDark)

            Spacer(minLength: 8)

            HStack(spacing: 9) {
                ForEach(CardTint.allCases) { candidate in
                    glassSwatch(candidate)
                }
            }
        }
    }

    @ViewBuilder
    private func glassSwatch(_ candidate: CardTint) -> some View {
        let locked = isLocked(candidate)

        Button {
            FeedbackManager.buttonPress()
            tint = candidate
        } label: {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(locked ? Color.white.opacity(0.42) : candidate.swatch)
                .frame(width: 38, height: 38)
                .overlay {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textMid)
                    } else if candidate == tint {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(theme.textDark)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            locked ? theme.dashColor : (candidate == tint ? theme.textDark : theme.hairline),
                            style: StrokeStyle(lineWidth: candidate == tint ? 1.5 : 1, dash: locked ? [4, 3] : [])
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked ? "\(candidate.name), locked" : candidate.name)
    }

    private func isLocked(_ candidate: CardTint) -> Bool {
        guard let requirement = candidate.unlockedBy else { return false }
        return !gameRoom.unlockedIDs.contains(requirement)
    }

    // MARK: Rank

    private var rankGrid: some View {
        Grid(horizontalSpacing: 9, verticalSpacing: 9) {
            GridRow {
                ForEach(Self.rankOrder[0..<5], id: \.self) { rankCell($0) }
            }
            GridRow {
                ForEach(Self.rankOrder[5..<10], id: \.self) { rankCell($0) }
            }
            GridRow {
                ForEach(Self.rankOrder[10..<13], id: \.self) { rankCell($0) }
                surpriseCell.gridCellColumns(2)
            }
        }
    }

    private func rankCell(_ candidate: Rank) -> some View {
        Button {
            FeedbackManager.buttonPress()
            rank = candidate
        } label: {
            Text(candidate.symbol)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(theme.textDark)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(candidate == rank ? theme.accentTint : theme.glassTint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(candidate == rank ? theme.textDark : theme.hairline,
                                lineWidth: candidate == rank ? 1.5 : 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.name)
    }

    /// Picks for you, for when the point is that you did not choose.
    private var surpriseCell: some View {
        Button {
            FeedbackManager.impact(.medium)
            rank = Self.rankOrder.randomElement() ?? .ace
            suit = Suit.allCases.randomElement() ?? .spades
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Surprise me")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(theme.textMid)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
