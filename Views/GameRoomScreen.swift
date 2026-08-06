import SwiftUI

/// §7 — the shelf. Categories stack down the page on lit glass ledges so the whole
/// room reads at a glance. Locked things are silhouettes wearing their own condition;
/// there are no counters and no progress bars.
struct GameRoomScreen: View {
    @ObservedObject var gameRoom: GameRoomStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(
                title: "Game Room",
                subtitle: "Things you have found, sitting where you left them.",
                onBack: { screen = .hub }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(RoomCategory.allCases) { category in
                        Shelf(gameRoom: gameRoom, category: category)
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onAppear { gameRoom.markShelfSeen() }
    }
}

private struct Shelf: View {
    @ObservedObject var gameRoom: GameRoomStore
    let category: RoomCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: category.title, trailing: gameRoom.countLabel(for: category))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: category == .chipSets ? 14 : 12) {
                    ForEach(gameRoom.items(in: category)) { item in
                        ShelfItem(gameRoom: gameRoom, item: item)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }

            ShelfLedge()
        }
    }
}

private struct ShelfItem: View {
    @ObservedObject var gameRoom: GameRoomStore
    @Environment(\.theme) private var theme

    let item: RoomItem

    var body: some View {
        Button {
            gameRoom.select(item)
        } label: {
            content
                .overlay(alignment: .topTrailing) {
                    if gameRoom.isNew(item) {
                        GlowDot()
                            .offset(x: 4, y: -4)
                    }
                }
                .overlay {
                    if gameRoom.isSelected(item) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(theme.accentColor, lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!gameRoom.isUnlocked(item) || item.category == .decor)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        if gameRoom.isUnlocked(item) {
            switch item.category {
            case .cardBacks:
                // Shows the actual design, so picking a back is a choice between
                // objects rather than between colours.
                swatchTile(width: 62, height: 88)
                    .overlay {
                        CardBackPattern(design: item.cardBackDesign ?? .lattice)
                            .padding(3)
                    }
            case .chipSets:
                chipTrio
            case .felts:
                swatchTile(width: 56, height: 38)
            case .decor:
                decorTile
            }
        } else {
            SilhouetteTile(
                caption: item.trigger.caption,
                width: size.width,
                height: size.height,
                cornerRadius: cornerRadius
            )
        }
    }

    private func swatchTile(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(item.swatch)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 5, y: 4)
    }

    private var chipTrio: some View {
        HStack(spacing: -16) {
            ForEach(Array(item.palette.enumerated()), id: \.offset) { _, color in
                // The real bead, unlabelled — a set should be picked by how it looks
                // on the felt, not by a flat swatch.
                GlassBead(color: color, label: "", size: 44)
            }
        }
        .frame(height: 44)
    }

    private var decorTile: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(item.swatch)
            .frame(width: 40, height: 52)
            .overlay {
                Image(systemName: item.symbol ?? "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textDark.opacity(0.7))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            }
    }

    private var size: CGSize {
        switch item.category {
        case .cardBacks: CGSize(width: 62, height: 88)
        case .chipSets: CGSize(width: 44, height: 44)
        case .felts: CGSize(width: 56, height: 38)
        case .decor: CGSize(width: 40, height: 52)
        }
    }

    private var cornerRadius: CGFloat {
        switch item.category {
        case .cardBacks: 12
        case .chipSets: 22
        case .felts: 10
        case .decor: 8
        }
    }

    private var accessibilityText: String {
        guard gameRoom.isUnlocked(item) else {
            return "Locked: \(item.trigger.caption.replacingOccurrences(of: "\n", with: " "))"
        }
        return gameRoom.isSelected(item) ? "\(item.name), in use" : item.name
    }
}
