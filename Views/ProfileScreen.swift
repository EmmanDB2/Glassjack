import SwiftUI

/// 3a — who you are, built from parts that already exist: capsule glass, an 88pt
/// card, the shelf metaphor from the Game Room, the six-letter code from
/// multiplayer. Cosmetics read as belongings rather than a settings list.
struct ProfileScreen: View {
    @ObservedObject var game: BlackjackGame
    @ObservedObject var gameRoom: GameRoomStore
    @ObservedObject var profile: ProfileStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    @State private var isPickingCard = false
    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    identityCard
                    lifetimeRow
                    bestHandRow
                    equippedShelf
                    destinationRows
                }
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .overlay {
            if isPickingCard {
                FavouriteCardPicker(
                    profile: profile,
                    gameRoom: gameRoom,
                    onClose: { isPickingCard = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.28), value: isPickingCard)
        .alert("Your name", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                profile.name = trimmed.isEmpty ? "You" : trimmed
            }
        } message: {
            Text("Shown to anyone you play with.")
        }
    }

    private var header: some View {
        HStack {
            Text("You")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .kerning(-0.8)
                .foregroundStyle(theme.textDark)

            Spacer(minLength: 8)

            GlassIconButton(
                systemImage: "xmark",
                size: 40,
                tint: theme.glassTint,
                accessibilityText: "Back to the hub",
                action: { screen = .hub }
            )
        }
    }

    // MARK: Identity

    /// The favourite card is the avatar — a real card, tilted, with a tinted shadow
    /// twin behind it and an edit badge in the corner.
    private var identityCard: some View {
        HStack(spacing: 16) {
            Button {
                FeedbackManager.buttonPress()
                isPickingCard = true
            } label: {
                favouriteAvatar
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Favourite card, \(profile.favouriteDescription). Tap to change.")

            VStack(alignment: .leading, spacing: 7) {
                Button {
                    draftName = profile.name
                    isRenaming = true
                } label: {
                    HStack(spacing: 7) {
                        Text(profile.name)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .kerning(-0.5)
                            .foregroundStyle(theme.textDark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textMid)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("Favourite card · \(profile.favouriteDescription)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)
                    .lineLimit(2)

                friendCodePill
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(theme.glassTint, cornerRadius: 28)
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private var favouriteAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            // The shadow twin, in the same glass, so the card looks like one of a pair.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(profile.favouriteTint.cardTint)
                .frame(width: 88, height: 125)
                .rotationEffect(.degrees(-7))
                .offset(x: 3, y: 3)

            PlayingCardView(card: profile.favouriteCard, isFaceDown: false, tint: profile.favouriteTint.cardTint)
                .frame(width: 88, height: 125)
                .rotationEffect(.degrees(-3.5))

            Image(systemName: "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.accentColor))
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                .offset(x: 4, y: 4)
        }
        .frame(width: 96, height: 130)
    }

    private var friendCodePill: some View {
        Button {
            profile.copyFriendCode()
            game.say("Code copied", icon: "doc.on.doc.fill")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textDark)

                Text(profile.friendCode)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .kerning(1.1)
                    .foregroundStyle(theme.textDark)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textMid)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .glassCapsule(theme.pillTint, interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Friend code \(profile.friendCode.map(String.init).joined(separator: " ")). Tap to copy.")
    }

    // MARK: Lifetime

    private var lifetimeRow: some View {
        HStack(spacing: 10) {
            LifetimeTile(
                value: gameRoom.stats.handsPlayed.formattedMoney,
                caption: "Hands played",
                ink: theme.textDark,
                background: theme.glassTint
            )
            LifetimeTile(
                value: winRateLabel,
                caption: "Win rate",
                ink: Color(hex: 0x0E8F86),
                background: theme.glassTint
            )
            LifetimeTile(
                value: "\(gameRoom.stats.blackjacks)",
                caption: "Blackjacks",
                ink: theme.textDark,
                background: theme.accentTint.opacity(0.7)
            )
        }
    }

    private var winRateLabel: String {
        guard gameRoom.stats.handsPlayed > 0 else { return "—" }
        return String(format: "%.1f%%", gameRoom.stats.winRate * 100)
    }

    // MARK: Best hand

    private var bestHandRow: some View {
        HStack(spacing: 13) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC9A227))

            VStack(alignment: .leading, spacing: 1) {
                Text(gameRoom.stats.biggestPot > 0
                     ? "Biggest pot · \(gameRoom.stats.biggestPot.money)"
                     : "No pots yet")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)

                Text(bestHandDetail)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(theme.glassTint, cornerRadius: 22)
    }

    private var bestHandDetail: String {
        guard gameRoom.stats.biggestPot > 0 else {
            return "Your best round will show up here"
        }
        let floor = gameRoom.stats.biggestPotFloor
        let blackjacks = gameRoom.stats.blackjacks
        return floor.isEmpty
            ? "\(blackjacks) blackjacks so far"
            : "\(floor) · \(blackjacks) blackjacks so far"
    }

    // MARK: Equipped

    /// The shelf metaphor again, but showing only what is actually in use.
    private var equippedShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Equipped")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)

                Text("from the Game Room")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)

                Spacer(minLength: 8)

                Button {
                    FeedbackManager.buttonPress()
                    screen = .gameRoom
                } label: {
                    Text("Shelf")
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundStyle(theme.primaryColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(equippedItems) { item in
                        EquippedTile(item: item, isLocked: !gameRoom.isUnlocked(item))
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    /// What is on right now, plus the next thing still behind glass.
    private var equippedItems: [RoomItem] {
        let equipped = [
            RoomItem.catalog.first { $0.id == gameRoom.selectedCardBackID },
            RoomItem.catalog.first { $0.id == gameRoom.selectedFeltID },
            RoomItem.catalog.first { $0.id == gameRoom.selectedChipSetID }
        ].compactMap { $0 }

        let nextLocked = RoomItem.catalog.first { !gameRoom.isUnlocked($0) }
        return equipped + [nextLocked].compactMap { $0 }
    }

    // MARK: Rows

    private var destinationRows: some View {
        VStack(spacing: 9) {
            HStack(spacing: 13) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x6E5DAE))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Fractured stack")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textDark)
                    Text("Kept apart from your balance")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                }

                Spacer(minLength: 8)

                Text(game.sessionStack.formattedMoney)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassSurface(theme.glassTint, cornerRadius: 22)

            Button {
                FeedbackManager.buttonPress()
                screen = .settings
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(theme.textDark)

                    Text("Settings")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textDark)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textMid)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glassSurface(theme.glassTint, cornerRadius: 22, interactive: true)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Pieces

private struct LifetimeTile: View {
    @Environment(\.theme) private var theme

    let value: String
    let caption: String
    let ink: Color
    let background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.textMid)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(background, cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

private struct EquippedTile: View {
    @Environment(\.theme) private var theme

    let item: RoomItem
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            swatch
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(item.name)
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundStyle(isLocked ? theme.textMid : theme.textDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(11)
        .frame(width: 92)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked ? "\(item.name), locked" : "\(item.name), equipped")
    }

    @ViewBuilder
    private var swatch: some View {
        if isLocked {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.silhouette)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.textMid)
                }
        } else {
            switch item.category {
            case .cardBacks:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.swatch)
                    .overlay { CardBackPattern(design: item.cardBackDesign ?? .lattice).padding(4) }
            case .chipSets:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .overlay { chipPair }
            case .felts, .decor:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.swatch)
            }
        }
    }

    private var chipPair: some View {
        HStack(spacing: -8) {
            ForEach(Array(item.palette.prefix(2).enumerated()), id: \.offset) { _, color in
                GlassBead(color: color, label: "", size: 26)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isLocked {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.glassTint.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
        } else {
            // No per-tile "selected" ring: everything in this row is equipped by
            // definition, so the section heading already says it.
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.glassTint)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.hairline, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        }
    }
}
