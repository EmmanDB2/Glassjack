import SwiftUI

/// The felt. Header pills and one grid button, the floor line, dealer, bet, player,
/// and a dock that changes with the phase — no other chrome.
struct TableScreen: View {
    @ObservedObject var game: BlackjackGame
    @ObservedObject var gameRoom: GameRoomStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme
    @Environment(\.glassBlurEnabled) private var glassBlurEnabled

    /// Wordmark plus floor line. Most of the space stays reserved while they are
    /// hidden, so the hands hold their place — but a little is handed back, so the
    /// table drifts up into the gap rather than leaving it empty.
    private var chromeHeight: CGFloat {
        game.phase == .betting ? 108 : 60
    }

    /// The betting dock is the tallest of the three. Holding that height keeps the
    /// player's cards still and puts every dock's buttons on one baseline.
    private let dockHeight: CGFloat = 114

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 12)

            tableChrome
                .frame(height: chromeHeight)

            DealerArea(game: game)
                .padding(.horizontal, 18)
                .padding(.top, 16)

            felt

            PlayerArea(game: game)
                .padding(.horizontal, 18)

            dock
                .frame(height: dockHeight, alignment: .bottom)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .animation(.snappy(duration: 0.35), value: game.phase)
        .overlay {
            if game.isOfferingInsurance {
                InsuranceOverlay(game: game)
                    .padding(22)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            // No Bet pill up here — the bet already reads on the felt, beside its pile.
            GlassPill(
                title: game.isFractured ? "Stack" : "Balance",
                amount: game.spendable,
                systemImage: "banknote.fill",
                reactsToChanges: true
            )
            // Hung below the pill as an overlay, so it changes neither the header's
            // height nor its width and nothing on the table shifts when it appears.
            .overlay(alignment: .bottomLeading) {
                if let deadline = game.grantDeadline {
                    GrantCountdown(deadline: deadline, amount: game.rules.bankruptGrantAmount)
                        .fixedSize()
                        .offset(y: GrantCountdown.height + 6)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }

            Spacer(minLength: 4)

            GlassIconButton(
                systemImage: "square.grid.2x2.fill",
                showsGlow: gameRoom.hasUndiscoveredItems,
                accessibilityText: "Open the hub",
                action: { screen = .hub }
            )
        }
    }

    /// Both pieces clear out of the way once cards are on the felt. They fade and
    /// slide up, but the block keeps its height so nothing below it moves.
    private var tableChrome: some View {
        ZStack(alignment: .top) {
            Color.clear

            if game.phase == .betting {
                VStack(spacing: 0) {
                    wordmark
                        .padding(.top, 20)

                    floorLine
                        .padding(.top, 14)
                }
                .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 12) {
            wordmarkSparkle
            glassTitle
            wordmarkSparkle
        }
        .frame(maxWidth: .infinity)
    }

    private var wordmarkSparkle: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.primaryColor.opacity(0.5))
    }

    private var titleText: some View {
        Text("Glassjack")
            .font(theme.wordmarkFont)
            .kerning(-0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    /// The wordmark cast in the room's own glass rather than painted on it: a
    /// tinted glass surface masked to the letterforms, so it refracts whatever the
    /// felt is doing behind it. Falls back to solid ink when blur is off (§11.1).
    @ViewBuilder
    private var glassTitle: some View {
        if glassBlurEnabled {
            titleText
                .hidden()
                .overlay {
                    Rectangle()
                        .fill(theme.primaryColor.opacity(0.42))
                        .glassEffect(.regular.tint(theme.primaryColor.opacity(0.30)), in: Rectangle())
                        .mask { titleText }
                }
        } else {
            titleText.foregroundStyle(theme.primaryColor)
        }
    }

    /// A shortcut straight to the table picker, showing what you are sitting at.
    private var floorLine: some View {
        Button {
            FeedbackManager.buttonPress()
            screen = .floors
        } label: {
            HStack(spacing: 8) {
                Image(systemName: game.preset.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryColor)

                Text(game.preset.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textDark)

                Text(game.preset.limitsLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textMid)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textMid)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .glassCapsule(theme.glassTint, interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Table: \(game.preset.name), \(game.preset.limitsLabel)")
    }

    // MARK: Felt

    private var felt: some View {
        ZStack {
            if !game.betStack.isEmpty {
                BetChipStack(
                    chips: game.betStack,
                    total: game.player.currentBet,
                    isClearable: game.phase == .betting,
                    sweep: game.chipSweep,
                    onClear: game.clearBet
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Dock

    @ViewBuilder
    private var dock: some View {
        switch game.phase {
        case .betting:
            BettingDock(game: game)
                .transition(.move(edge: .bottom).combined(with: .opacity))

        case .playerTurn, .dealerTurn:
            ActionDock(game: game)
                .transition(.move(edge: .bottom).combined(with: .opacity))

        case .roundOver:
            RoundOverDock(game: game, screen: $screen)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// §5 — at zero the grant is already on its way. This says when, so the wait reads
/// as a promise rather than a dead end.
private struct GrantCountdown: View {
    @Environment(\.theme) private var theme

    /// Fixed so the caller can hang it below the pill without measuring.
    static let height: CGFloat = 22

    let deadline: Date
    let amount: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10, weight: .bold))

            Text("\(amount.money) in")
                .font(.system(size: 11, weight: .bold, design: .rounded))

            // Updates itself — no per-second work anywhere else in the app.
            Text(timerInterval: Date()...safeDeadline, countsDown: true)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(theme.textMid)
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .glassCapsule(theme.glassTint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount.money) arriving shortly")
    }

    /// A deadline that has already passed would be an invalid range.
    private var safeDeadline: Date {
        max(deadline, Date().addingTimeInterval(1))
    }
}

// MARK: - Dealer

private struct DealerArea: View {
    @ObservedObject var game: BlackjackGame
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 11) {
            ZStack {
                HandTitle(name: "Dealer", total: game.visibleDealerTotal, tint: theme.pillTint)

                HStack {
                    Spacer(minLength: 0)
                    ShoeIndicator(
                        count: game.shoeCountLabel,
                        fraction: game.shoeRemainingFraction
                    )
                }
            }
            .frame(maxWidth: .infinity)

            HandCardsView(
                cards: game.dealerHand.cards,
                hiddenIndex: game.dealerHoleRevealed ? nil : 1,
                emptySymbol: "rectangle.stack.fill"
            )
        }
    }
}

/// §5 — the card count is deliberately visible, as a number and as a bar.
private struct ShoeIndicator: View {
    @Environment(\.theme) private var theme

    let count: String
    let fraction: Double

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        HStack(spacing: 6) {
            Text(count)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textMid)
                .contentTransition(.numericText())

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .overlay(Capsule().stroke(theme.hairline, lineWidth: 1))

                GeometryReader { proxy in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.78), theme.accentColor.opacity(0.62)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(4, (proxy.size.width - 4) * clamped),
                            height: max(3, proxy.size.height - 4)
                        )
                        .padding(2)
                }
            }
            .frame(width: 64, height: 10)
            .animation(.snappy(duration: 0.2), value: clamped)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) cards left in the shoe")
    }
}

// MARK: - Player

private struct PlayerArea: View {
    @ObservedObject var game: BlackjackGame
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 11) {
            if game.playerHands.count <= 1 {
                HandTitle(name: "You", total: game.visiblePlayerTotal, tint: theme.glassTint)
                HandCardsView(
                    cards: game.playerHands.first?.cards ?? [],
                    hiddenIndex: nil,
                    emptySymbol: "person.fill"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(game.playerHands.enumerated()), id: \.element.id) { index, hand in
                            SplitHandView(
                                index: index,
                                hand: hand,
                                isActive: game.phase == .playerTurn && game.activeHandIndex == index
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 190)
            }

            Text(game.statusLine)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(game.phase == .betting ? theme.primaryColor : theme.textMid)
                .contentTransition(.numericText())
                .frame(height: 22)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SplitHandView: View {
    @Environment(\.theme) private var theme

    let index: Int
    let hand: Hand
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            HandTitle(name: "Hand \(index + 1)", total: "\(hand.score.total)", tint: theme.accentTint)
            HandCardsView(cards: hand.cards, hiddenIndex: nil, cardWidth: 70, overlap: 34)
                .frame(width: 150, height: 112)
            Text(hand.bet.money)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassCapsule(isActive ? theme.accentTint : theme.glassTint)
        }
        .padding(8)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActive ? theme.accentColor.opacity(0.8) : .clear, lineWidth: 2)
        }
    }
}

private struct HandTitle: View {
    @Environment(\.theme) private var theme

    let name: String
    let total: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textDark)

            Text(total)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textDark)
                .contentTransition(.numericText())
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .glassCapsule(tint)
        }
    }
}

struct HandCardsView: View {
    let cards: [Card]
    let hiddenIndex: Int?
    var cardWidth: CGFloat = 88
    var overlap: CGFloat = 44
    var emptySymbol: String?

    var body: some View {
        ZStack {
            if cards.isEmpty {
                EmptyHandPlaceholder(symbol: emptySymbol)
            }

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                PlayingCardView(card: card, isFaceDown: hiddenIndex == index)
                    .frame(width: cardWidth, height: cardWidth * 1.42)
                    .offset(x: CGFloat(index) * overlap - CGFloat(max(cards.count - 1, 0)) * overlap / 2)
                    .zIndex(Double(index))
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(height: cardWidth * 1.42)
    }
}

private struct EmptyHandPlaceholder: View {
    @Environment(\.theme) private var theme

    let symbol: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(theme.ghostColor)
            }
        }
        .frame(width: 96, height: 125)
        .accessibilityHidden(true)
    }
}

// MARK: - Docks

private struct BettingDock: View {
    @ObservedObject var game: BlackjackGame
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(game.chipDenominations) { denomination in
                    ChipButton(
                        denomination: denomination,
                        isEnabled: game.canAddChip(denomination),
                        action: { game.addChip(denomination) }
                    )
                }
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    PrimaryAction(
                        title: "Clear",
                        systemImage: "xmark.circle",
                        isEnabled: game.player.currentBet > 0,
                        action: game.clearBet
                    )

                    PrimaryAction(
                        title: "Deal",
                        systemImage: "play.fill",
                        tint: theme.accentTint,
                        isEnabled: game.canDeal,
                        action: game.deal
                    )
                }
            }
        }
    }
}

private struct ActionDock: View {
    @ObservedObject var game: BlackjackGame

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ActionButton(title: "Hit", systemImage: "plus.circle.fill",
                             tint: Color(hex: 0x34C759, opacity: 0.26),
                             isEnabled: game.canHit, action: game.hit)

                ActionButton(title: "Stand", systemImage: "hand.raised.fill",
                             tint: Color(hex: 0xFF9500, opacity: 0.26),
                             isEnabled: game.canStand, action: game.stand)

                ActionButton(title: "Double", systemImage: "2.circle.fill",
                             tint: Color(hex: 0x007AFF, opacity: 0.26),
                             isEnabled: game.canDoubleDown, action: game.doubleDown)

                if game.canSplit {
                    ActionButton(title: "Split", systemImage: "arrow.triangle.branch",
                                 tint: Color(hex: 0x8E7DC6, opacity: 0.30),
                                 isEnabled: true, action: game.split)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 54)
        }
        .animation(.snappy(duration: 0.25), value: game.canSplit)
    }
}

private struct ActionButton: View {
    @Environment(\.theme) private var theme

    let title: String
    let systemImage: String
    let tint: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackManager.buttonPress()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(theme.textDark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassSurface(tint, cornerRadius: 26, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(title)
    }
}

private struct RoundOverDock: View {
    @ObservedObject var game: BlackjackGame
    @Binding var screen: AppScreen
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                PrimaryAction(title: "Summary", systemImage: "list.bullet.rectangle") {
                    screen = .summary
                }

                PrimaryAction(
                    title: game.rebetLabel,
                    systemImage: "arrow.counterclockwise",
                    tint: theme.accentTint,
                    action: game.rebetLastAmount
                )
            }
        }
    }
}

// MARK: - Insurance

private struct InsuranceOverlay: View {
    @ObservedObject var game: BlackjackGame
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text("Insurance")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)
                Text("Up to \(game.maxInsurance.money)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textMid)
            }

            Stepper(value: $game.insuranceDraft, in: 0...max(game.maxInsurance, 0)) {
                Text(game.insuranceDraft.money)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
            }

            HStack(spacing: 12) {
                PrimaryAction(title: "No bet", action: game.declineInsurance)
                PrimaryAction(title: "Confirm", tint: theme.accentTint, action: game.commitInsurance)
            }
        }
        .padding(22)
        .frame(maxWidth: 330)
        .glassSurface(Color.white.opacity(0.35), cornerRadius: 26)
        .shadow(color: .black.opacity(0.14), radius: 24, y: 14)
    }
}
