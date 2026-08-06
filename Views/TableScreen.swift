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

    /// Sized off the *betting* chrome even while the chrome is away, so the table
    /// keeps one height all round. When the wordmark clears out the slab drifts up
    /// into the gap rather than stretching into it — the cards hold their place.
    private func slabHeight(in available: CGFloat) -> CGFloat {
        let reserved: CGFloat = 12 + 44 + 108 + 8 + countHeight + 6
            + 8 + countHeight + 6 + dockHeight + 14
        return max(280, available - reserved)
    }

    /// Both counts get the same row height, so the table sits centred between them.
    private let countHeight: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                tableChrome
                    .frame(height: chromeHeight)

                FeltNameplate(name: "Dealer", total: game.visibleDealerTotal, tint: theme.pillTint)
                    .frame(height: countHeight)
                    .padding(.top, 8)

                TableSlabView(game: game)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .frame(height: slabHeight(in: proxy.size.height) + 6)

                // The count and the round's message share a row. Stacked, they were
                // two centred pills a few points apart saying different halves of
                // the same thing — and the space they cost came out of the cards.
                HStack(spacing: 8) {
                    FeltNameplate(name: "You", total: game.visiblePlayerTotal, tint: theme.accentTint)
                    statusLine
                }
                .frame(height: countHeight)
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer(minLength: 0)

                dock
                    .frame(height: dockHeight, alignment: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
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

            if game.recentOutcomes.isEmpty {
                Spacer(minLength: 4)
            } else {
                StreakRail(outcomes: game.recentOutcomes, net: game.sessionNet)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            GlassIconButton(
                systemImage: "square.grid.2x2.fill",
                showsGlow: gameRoom.hasUndiscoveredItems,
                accessibilityText: "Open the hub",
                action: { screen = .hub }
            )
        }
        .animation(.snappy(duration: 0.3), value: game.recentOutcomes)
    }

    /// Was a bare line under the player's cards; now a pill, because the cards it
    /// used to sit under have moved onto the slab.
    private var statusLine: some View {
        Text(game.statusLine)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(game.phase == .betting ? theme.primaryColor : theme.textDark)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .glassCapsule(game.phase == .betting ? theme.accentTint : theme.glassTint)
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

/// How the session is going, at a glance: the last five hands as beads plus what
/// they add up to. Fills the dead space the header used to leave between the
/// balance and the hub button.
private struct StreakRail: View {
    @Environment(\.theme) private var theme

    let outcomes: [RoundOutcome]
    let net: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LAST \(outcomes.count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .kerning(0.8)
                .foregroundStyle(theme.textMid)

            HStack(spacing: 4) {
                ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                    OutcomeBead(outcome: outcome)
                }

                Text(net.signedMoney)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(net < 0 ? Color(hex: 0xA32C3B) : Color(hex: 0x1E7A36))
                    .contentTransition(.numericText())
                    .padding(.leading, 3)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCapsule(theme.glassTint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last \(outcomes.count) hands, \(net.signedMoney) overall")
    }
}

/// One hand, as a bead the same family as the chips.
private struct OutcomeBead: View {
    let outcome: RoundOutcome

    private var letter: String {
        switch outcome {
        case .blackjack: "B"
        case .win: "W"
        case .push: "P"
        case .loss, .bust: "L"
        }
    }

    private var colour: Color {
        switch outcome {
        case .blackjack: Color(hex: 0x00A79E)
        case .win: Color(hex: 0x34C759)
        case .push: Color(hex: 0xAAB2B9)
        case .loss, .bust: Color(hex: 0xD84A5A)
        }
    }

    var body: some View {
        Text(letter)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(outcome == .push ? Color(hex: 0x3C3C43, opacity: 0.7) : .white)
            .frame(width: 15, height: 15)
            .background {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.9), colour.opacity(0.9), colour],
                            center: UnitPoint(x: 0.32, y: 0.26),
                            startRadius: 0,
                            endRadius: 13
                        )
                    )
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color.white.opacity(0.4)],
                                    startPoint: .center, endPoint: .bottom
                                )
                            )
                    }
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

// MARK: - The table

/// §4 / design 1A — the felt as one slab of glass with the house rules etched into
/// it. Everything that used to be three stacked blocks (dealer row, bet, player row)
/// now lives on this one surface, placed against the printed markings the way it
/// would be on a real table.
private struct TableSlabView: View {
    @ObservedObject var game: BlackjackGame
    @Environment(\.theme) private var theme

    /// The printed rules always get this much of the middle. Smaller since the
    /// betting circle left — the chips sit on the printing now, not below it.
    private let bandHeight: CGFloat = 150
    /// With both counts now above and below the slab, nothing sits in the corners
    /// for the cards to run into, so the hands start close to the dealer's edge.
    private let topInset: CGFloat = 20
    private let bottomInset: CGFloat = 10

    /// Card height is whatever the slab can spare once the band has its share. Both
    /// hands change together, so the table stays symmetrical on every screen size.
    private func cardHeight(for slabHeight: CGFloat) -> CGFloat {
        min(max((slabHeight - topInset - bottomInset - bandHeight) / 2, 78), 125)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cardH = cardHeight(for: size.height)
            let cardW = cardH / 1.42
            let bandTop = topInset + cardH
            let playerCentre = size.height - bottomInset - cardH / 2

            ZStack(alignment: .topLeading) {
                slab

                TableMarkings(
                    width: size.width,
                    bandTop: bandTop,
                    rules: game.feltRuleLines
                )

                // Padding before the frame, not after: padding a view that is already
                // the full width makes it wider than the slab, and a topLeading ZStack
                // sizes to its widest child — which pushed the whole table right.
                ShoeTray(count: game.shoeCountLabel, fraction: game.shoeRemainingFraction)
                    .padding(.trailing, 12)
                    .padding(.top, 10)
                    .frame(width: size.width, alignment: .trailing)

                HandCardsView(
                    cards: game.dealerHand.cards,
                    hiddenIndex: game.dealerHoleRevealed ? nil : 1,
                    cardWidth: cardW,
                    overlap: cardW / 2,
                    emptySymbol: "rectangle.stack.fill"
                )
                .frame(width: size.width)
                .position(x: size.width / 2, y: topInset + cardH / 2)

                if !game.betStack.isEmpty {
                    BetChipStack(
                        chips: game.betStack,
                        total: game.player.currentBet,
                        isClearable: game.phase == .betting,
                        sweep: game.chipSweep,
                        onClear: game.clearBet
                    )
                    // Tossed onto the printing itself. The pile is narrower than the
                    // lines it lands on, so the rules still read out either side of it.
                    .position(x: size.width / 2, y: TableMarkings.rulesCentre(bandTop))
                    .transition(.opacity)
                }

                playerHands(width: size.width, cardWidth: cardW, centreY: playerCentre)
            }
        }
    }

    /// One pour of glass. The sheen is a slow highlight travelling across it, so the
    /// table reads as a surface rather than a panel even while nothing is happening.
    private var slab: some View {
        TableSlabShape()
            .fill(.clear)
            .glassFelt(theme.glassTint.opacity(0.55), in: TableSlabShape())
            .overlay {
                TableSlabShape()
                    .stroke(theme.hairline, lineWidth: 1)
            }
    }

    @ViewBuilder
    private func playerHands(width: CGFloat, cardWidth: CGFloat, centreY: CGFloat) -> some View {
        if game.playerHands.count <= 1 {
            HandCardsView(
                cards: game.playerHands.first?.cards ?? [],
                hiddenIndex: nil,
                cardWidth: cardWidth,
                overlap: cardWidth / 2,
                emptySymbol: "person.fill"
            )
            .frame(width: width)
            .position(x: width / 2, y: centreY)
        } else {
            // Splits need more room than the slot allows, so they scroll across it.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(game.playerHands.enumerated()), id: \.element.id) { index, hand in
                        SplitHandView(
                            index: index,
                            hand: hand,
                            cardWidth: cardWidth * 0.82,
                            isActive: game.phase == .playerTurn && game.activeHandIndex == index
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(width: width)
            .position(x: width / 2, y: centreY)
        }
    }
}

private struct SplitHandView: View {
    @Environment(\.theme) private var theme

    let index: Int
    let hand: Hand
    var cardWidth: CGFloat = 70
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            HandTitle(name: "Hand \(index + 1)", total: "\(hand.score.total)", tint: theme.accentTint)
            HandCardsView(cards: hand.cards, hiddenIndex: nil,
                          cardWidth: cardWidth, overlap: cardWidth / 2)
                .frame(width: cardWidth * 2.1)
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
                EmptyHandPlaceholder(symbol: emptySymbol, width: cardWidth)
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
    /// Matches the card that will land here, so the slot never outgrows the felt.
    var width: CGFloat = 88

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.22, style: .continuous)
                .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: width * 0.36, weight: .semibold))
                    .foregroundStyle(theme.ghostColor)
            }
        }
        .frame(width: width, height: width * 1.42)
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
                        title: game.dealLabel,
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
