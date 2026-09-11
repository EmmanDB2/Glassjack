import SwiftUI

/// A quiet line that slides in at the top of the screen. Never a popup — §7.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
}

/// What the round summary screen reads. Built once, when the round ends.
struct RoundSummary: Equatable {
    let outcome: RoundOutcome
    let title: String
    let net: Int
    let bet: Int
    let playerTotal: Int
    let dealerTotal: Int
    let discovery: RoomItem?

    var detail: String {
        "You \(playerTotal) · Dealer \(dealerTotal) · bet \(bet.money)"
    }
}

@MainActor
final class BlackjackGame: ObservableObject {
    // MARK: Table

    @Published private(set) var preset: TablePreset = .casinoFloor
    @Published private(set) var unlockedFloorIDs: Set<String>

    // MARK: Round state

    @Published private(set) var phase: GamePhase = .betting
    @Published private(set) var playerHands: [Hand] = []
    @Published private(set) var dealerHand = Hand()
    @Published private(set) var activeHandIndex = 0
    @Published private(set) var dealerHoleRevealed = false
    @Published private(set) var isDealing = false
    @Published private(set) var isOfferingInsurance = false
    @Published private(set) var insuranceBet = 0
    @Published private(set) var results: [ResolvedHand] = []
    @Published private(set) var roundMessage = "Place your bet"
    @Published private(set) var shoe = Shoe()
    @Published var player: Player
    @Published var insuranceDraft = 0
    @Published var activeTableEffect: TableEffect?

    /// Individual chips as they were tossed, so the felt can restack them.
    @Published private(set) var betStack: [PlacedChip] = []
    /// Set while the settled bet is being pushed across the felt to the winner.
    @Published private(set) var chipSweep: ChipSweep?

    // MARK: Session

    /// Fractured runs off this instead of the balance — §8, nothing carries over.
    @Published private(set) var sessionStack = 0
    @Published private(set) var handsThisSession = 0
    @Published private(set) var sessionNet = 0
    @Published private(set) var lastSummary: RoundSummary?
    @Published private(set) var toast: ToastMessage?
    @Published private(set) var ejectMessage: String?
    /// When the next bankrupt grant lands. Non-nil only while the player is at zero
    /// on a table that plays off the balance.
    @Published private(set) var grantDeadline: Date?

    // MARK: Fractured configuration

    @Published var fracturedModifiers: [RuleModifier] = RuleModifier.catalog
    @Published var fracturedWildCardCount = 6
    @Published var fracturedChallenge: ChallengeScenario? = ChallengeScenario.catalog.first

    let maxFracturedWildCards = 14

    private var gameRoom: GameRoomStore?
    private var settings: SettingsStore?
    private var toastTask: Task<Void, Never>?
    private var sweepTask: Task<Void, Never>?
    private var grantTask: Task<Void, Never>?
    /// Stakes sent to a shared table but not yet settled. This stays with the
    /// bankroll rather than a view so it can be refunded if the session ends.
    private var unsettledMultiplayerStake = 0

    private let defaults: UserDefaults
    private let balanceKey = "glassjack.player.balance"
    private let unlockedFloorsKey = "glassjack.floors.unlocked"
    private let lastLaunchDayKey = "glassjack.lastLaunchDay"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedBalance = defaults.object(forKey: balanceKey) as? Int
        let initialBalance = savedBalance ?? GameConfig.casinoFloor.startingBalance
        player = Player(balance: initialBalance, currentBet: 0, lastBet: 0)

        var unlocked = Set(defaults.stringArray(forKey: unlockedFloorsKey) ?? [])
        unlocked.insert(TablePreset.casinoFloor.id)
        unlocked.insert(TablePreset.fractured.id)
        unlockedFloorIDs = unlocked

        shoe = Shoe(deckCount: preset.rules.numberOfDecks)
        applyDailyRefillIfNeeded()
        refreshFloorUnlocks()
    }

    /// Wired up by `RootView` once the stores exist.
    func attach(gameRoom: GameRoomStore, settings: SettingsStore) {
        self.gameRoom = gameRoom
        self.settings = settings
        gameRoom.beginSession()
        refreshFloorUnlocks()
        updateBankruptGrant()
    }

    // MARK: - Config passthrough

    var rules: GameConfig { preset.rules }
    var isFractured: Bool { preset.isFractured }

    /// What the player can actually put on the table right now.
    var spendable: Int {
        isFractured ? sessionStack : player.balance
    }

    var chipDenominations: [ChipDenomination] {
        preset.theme.chipDenominations
    }

    // MARK: - Derived display state

    var activeHand: Hand? {
        guard playerHands.indices.contains(activeHandIndex) else { return nil }
        return playerHands[activeHandIndex]
    }

    var canDeal: Bool {
        phase == .betting && player.currentBet >= rules.minimumBet && !isDealing
    }

    var canHit: Bool {
        phase == .playerTurn && !isDealing && !isOfferingInsurance && activeHand?.isBust == false
    }

    var canStand: Bool {
        phase == .playerTurn && !isDealing && !isOfferingInsurance && activeHand != nil
    }

    var canDoubleDown: Bool {
        guard rules.allowDouble, let activeHand else { return false }
        return phase == .playerTurn
            && !isDealing
            && !isOfferingInsurance
            && activeHand.cards.count == 2
            && spendable >= activeHand.bet
    }

    var canSplit: Bool {
        guard rules.allowSplit, let firstHand = playerHands.first else { return false }
        return phase == .playerTurn
            && !isDealing
            && !isOfferingInsurance
            && playerHands.count < rules.maxSplitHands
            && playerHands.count == 1
            && firstHand.canSplitByRank
            && spendable >= firstHand.bet
    }

    var maxInsurance: Int {
        min(spendable, (playerHands.first?.bet ?? 0) / 2)
    }

    var visibleDealerTotal: String {
        guard !dealerHand.cards.isEmpty else { return "0" }
        if dealerHoleRevealed || phase == .roundOver {
            return "\(dealerHand.score.total)"
        }
        return "\(dealerHand.cards.first?.rank.blackjackValue ?? 0)+"
    }

    var visiblePlayerTotal: String {
        guard let activeHand, !activeHand.cards.isEmpty else { return "0" }
        return "\(activeHand.score.total)"
    }

    var shoeRemainingFraction: Double {
        shoe.cardsRemainingFraction
    }

    var shoeCountLabel: String {
        "\(shoe.remainingCount)"
    }

    var statusLine: String { roundMessage }

    var rebetLabel: String {
        player.lastBet > 0 ? "Bet \(player.lastBet.money)" : "New bet"
    }

    var canRebet: Bool {
        player.lastBet >= rules.minimumBet && player.lastBet <= spendable
    }

    // MARK: - Floors

    func isUnlocked(_ candidate: TablePreset) -> Bool {
        unlockedFloorIDs.contains(candidate.id)
    }

    /// Re-checks the locked floors against balance, clock and streak.
    func refreshFloorUnlocks() {
        var newlyOpened: [TablePreset] = []

        for floor in TablePreset.floors where !unlockedFloorIDs.contains(floor.id) {
            guard satisfies(floor.unlock) else { continue }
            unlockedFloorIDs.insert(floor.id)
            newlyOpened.append(floor)
        }

        guard !newlyOpened.isEmpty else { return }
        defaults.set(Array(unlockedFloorIDs), forKey: unlockedFloorsKey)
        if let first = newlyOpened.first {
            say("\(first.name) is open", icon: "door.left.hand.open")
        }
    }

    private func satisfies(_ requirement: UnlockRequirement) -> Bool {
        switch requirement {
        case .always:
            true
        case .balance(let amount):
            player.balance >= amount
        case .playAfterHour(let hour):
            DynamicLightingService.isAfter(hour: hour) || (gameRoom?.stats.latestHourPlayed ?? 0) >= hour
        case .dailyStreak(let days):
            (gameRoom?.stats.dailyStreak ?? 1) >= days
        }
    }

    var canChangeFloor: Bool {
        (phase == .betting || phase == .roundOver) && !isDealing
    }

    /// Moves to another floor, charging the entry fee and rebuilding the shoe.
    func enter(_ next: TablePreset) {
        guard canChangeFloor, isUnlocked(next) else { return }
        guard next.id != preset.id else { return }

        if next.rules.entryFee > 0 {
            guard player.balance >= next.rules.entryFee else {
                say("\(next.name) costs \(next.rules.entryFee.money) to sit down", icon: "lock.fill")
                return
            }
            player.balance -= next.rules.entryFee
            persistBalance()
        }

        preset = next
        sessionStack = next.rules.usesSessionStack ? next.rules.sessionStack : 0
        shoe = Shoe(deckCount: next.rules.numberOfDecks)
        resetForBetting(currentBet: 0)
        MusicManager.shared.switchPlaylist(to: next.theme.musicTracks)
        updateBankruptGrant()
        FeedbackManager.impact(.medium)
    }

    /// Enters Fractured with whatever the lobby is currently configured to.
    func enterFractured() {
        var configured = TablePreset.fractured
        var configuredRules = configured.rules
        configuredRules.modifiers = fracturedModifiers
        configuredRules.wildCards = Array(
            WildCardDefinition.catalog.prefix(max(1, min(fracturedWildCardCount, WildCardDefinition.catalog.count)))
        )
        configuredRules.challenge = fracturedChallenge
        configured = TablePreset(
            id: configured.id,
            name: configured.name,
            iconName: configured.iconName,
            tagline: configured.tagline,
            rules: configuredRules,
            theme: configured.theme,
            unlock: configured.unlock
        )

        preset = configured
        sessionStack = configuredRules.sessionStack
        shoe = Shoe(deckCount: configuredRules.numberOfDecks)
        resetForBetting(currentBet: 0)
        MusicManager.shared.switchPlaylist(to: configured.theme.musicTracks)
        updateBankruptGrant()
        FeedbackManager.impact(.medium)
    }

    private func enterCasinoFloorDirectly() {
        preset = .casinoFloor
        sessionStack = 0
        shoe = Shoe(deckCount: TablePreset.casinoFloor.rules.numberOfDecks)
        resetForBetting(currentBet: 0)
        MusicManager.shared.switchPlaylist(to: TablePreset.casinoFloor.theme.musicTracks)
        updateBankruptGrant()
    }

    // MARK: - Betting

    func canAddChip(_ denomination: ChipDenomination) -> Bool {
        phase == .betting
            && player.currentBet + denomination.value <= spendable
            && player.currentBet + denomination.value <= rules.maximumBet
    }

    func addChip(_ denomination: ChipDenomination) {
        guard canAddChip(denomination) else { return }
        player.currentBet += denomination.value
        betStack.append(
            PlacedChip(
                value: denomination.value,
                label: denomination.label,
                color: denomination.color,
                index: betStack.count
            )
        )
        roundMessage = player.currentBet >= rules.minimumBet
            ? "Ready when you are"
            : "Minimum bet \(rules.minimumBet.money)"
        FeedbackManager.chipLand()
        SoundManager.shared.play(.chipBet)
    }

    func clearBet() {
        guard phase == .betting, player.currentBet > 0 else { return }
        cancelBetSweep()
        withAnimation(.snappy(duration: 0.28)) {
            player.currentBet = 0
            betStack = []
        }
        roundMessage = "Place your bet"
        FeedbackManager.impact(.light)
    }

    func deal() {
        guard canDeal else { return }

        prepareShoeForRoundIfNeeded()
        let openingBet = player.currentBet
        player.lastBet = openingBet
        debit(openingBet)
        dealerHand = Hand()
        playerHands = [Hand(bet: openingBet)]
        activeHandIndex = 0
        dealerHoleRevealed = false
        insuranceBet = 0
        insuranceDraft = 0
        results = []
        roundMessage = "Dealing"
        isDealing = true

        withAnimation(.snappy(duration: 0.35)) {
            phase = .playerTurn
        }

        Task { await dealOpeningCards() }
    }

    // MARK: - Player actions

    func commitInsurance() {
        guard isOfferingInsurance else { return }
        let committedBet = min(max(insuranceDraft, 0), maxInsurance)
        insuranceBet = committedBet
        if committedBet > 0 {
            debit(committedBet)
        }

        isOfferingInsurance = false
        insuranceDraft = 0
        FeedbackManager.impact(.medium)
        finishDealerPeek()
    }

    func declineInsurance() {
        guard isOfferingInsurance else { return }
        insuranceDraft = 0
        commitInsurance()
    }

    func hit() {
        guard canHit else { return }
        Task { await hitActiveHand() }
    }

    func stand() {
        guard canStand else { return }
        if playerHands.indices.contains(activeHandIndex) {
            playerHands[activeHandIndex].isStanding = true
        }
        FeedbackManager.impact(.light)
        advanceAfterActiveHand()
    }

    func doubleDown() {
        guard canDoubleDown else { return }
        Task { await doubleActiveHand() }
    }

    func split() {
        guard canSplit, let originalHand = playerHands.first else { return }
        Task { await splitOpeningHand(originalHand) }
    }

    func startNextRound() {
        resetForBetting(currentBet: 0)
    }

    func rebetLastAmount() {
        guard canRebet else {
            resetForBetting(currentBet: 0)
            return
        }
        resetForBetting(currentBet: player.lastBet)
        rebuildStack(for: player.lastBet)
    }

    func resetBankroll() {
        player.balance = rules.startingBalance
        player.currentBet = 0
        player.lastBet = 0
        persistBalance()
        startNextRound()
        say("Back to \(rules.startingBalance.money)", icon: "arrow.counterclockwise")
    }

    func clearEjectMessage() {
        ejectMessage = nil
    }

    // MARK: - Toast

    func say(_ text: String, icon: String = "sparkles") {
        toastTask?.cancel()
        withAnimation(.snappy(duration: 0.28)) {
            toast = ToastMessage(text: text, icon: icon)
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.snappy(duration: 0.28)) {
                    self?.toast = nil
                }
            }
        }
    }

    // MARK: - Dealing

    private func dealOpeningCards() async {
        await dealCard(to: .player(index: 0))
        await dealCard(to: .dealer)
        await dealCard(to: .player(index: 0))
        await dealCard(to: .dealer)
        isDealing = false
        evaluateOpeningDeal()
    }

    private func evaluateOpeningDeal() {
        guard let upcard = dealerHand.cards.first else { return }

        if rules.allowInsurance && upcard.rank == .ace {
            isOfferingInsurance = true
            insuranceDraft = maxInsurance
            roundMessage = "Insurance"
            return
        }

        if rules.dealerPeeksForBlackjack && (upcard.rank.isTenValue || upcard.rank == .ace) {
            finishDealerPeek()
            return
        }

        if playerHands.first?.isNaturalBlackjack == true {
            revealDealerHole()
            settleRound()
        } else {
            roundMessage = "Your move"
        }
    }

    private func finishDealerPeek() {
        if dealerHand.isNaturalBlackjack {
            revealDealerHole()
            resolveDealerBlackjack()
            return
        }

        if playerHands.first?.isNaturalBlackjack == true {
            revealDealerHole()
            settleRound()
        } else {
            roundMessage = "Your move"
        }
    }

    private func hitActiveHand() async {
        guard playerHands.indices.contains(activeHandIndex) else { return }
        isDealing = true
        await dealCard(to: .player(index: activeHandIndex))
        isDealing = false

        guard let activeHand else { return }
        if activeHand.isBust || activeHand.score.total == 21 {
            playerHands[activeHandIndex].isStanding = true
            advanceAfterActiveHand()
        }
    }

    private func doubleActiveHand() async {
        guard playerHands.indices.contains(activeHandIndex) else { return }
        let additionalBet = playerHands[activeHandIndex].bet
        debit(additionalBet)
        player.currentBet += additionalBet
        playerHands[activeHandIndex].bet += additionalBet
        isDealing = true
        await dealCard(to: .player(index: activeHandIndex))
        isDealing = false
        playerHands[activeHandIndex].isStanding = true
        FeedbackManager.impact(.medium)
        advanceAfterActiveHand()
    }

    private func splitOpeningHand(_ originalHand: Hand) async {
        guard originalHand.cards.count == 2 else { return }
        let splitBet = originalHand.bet
        debit(splitBet)
        player.currentBet += splitBet

        playerHands = [
            Hand(cards: [originalHand.cards[0]], bet: splitBet, isFromSplit: true),
            Hand(cards: [originalHand.cards[1]], bet: splitBet, isFromSplit: true)
        ]
        activeHandIndex = 0
        roundMessage = "Hand 1"
        FeedbackManager.impact(.medium)

        isDealing = true
        await dealCard(to: .player(index: 0))
        await dealCard(to: .player(index: 1))
        isDealing = false
    }

    private func advanceAfterActiveHand() {
        if activeHandIndex + 1 < playerHands.count {
            activeHandIndex += 1
            roundMessage = "Hand \(activeHandIndex + 1)"
            return
        }

        if playerHands.allSatisfy(\.isBust) {
            let shouldPlayFlip = !dealerHoleRevealed
            withAnimation(.smooth(duration: 0.45)) {
                phase = .dealerTurn
                dealerHoleRevealed = true
            }
            playDealerHoleFlipIfNeeded(shouldPlay: shouldPlayFlip)
            settleRound()
            return
        }

        Task { await playDealerTurn() }
    }

    private func playDealerTurn() async {
        let shouldPlayFlip = !dealerHoleRevealed
        withAnimation(.smooth(duration: 0.45)) {
            phase = .dealerTurn
            dealerHoleRevealed = true
        }
        playDealerHoleFlipIfNeeded(shouldPlay: shouldPlayFlip)
        roundMessage = "Dealer turn"
        try? await Task.sleep(nanoseconds: 550_000_000)

        while shouldDealerHit {
            isDealing = true
            await dealCard(to: .dealer)
            isDealing = false
            try? await Task.sleep(nanoseconds: 450_000_000)
        }

        settleRound()
    }

    private var shouldDealerHit: Bool {
        let score = dealerHand.score
        if score.total <= 16 {
            return true
        }
        if score.total == 17 && score.isSoft && rules.dealerHitsSoft17 {
            return true
        }
        return false
    }

    // MARK: - Settling

    private func resolveDealerBlackjack() {
        let insuranceReturn = insuranceBet > 0 ? rules.insuranceReturn(for: insuranceBet) : 0
        var payout = insuranceReturn
        var resolved: [ResolvedHand] = []

        for (index, hand) in playerHands.enumerated() {
            if hand.isNaturalBlackjack {
                let pushBack = rules.pushReturn(for: hand.bet)
                payout += pushBack
                resolved.append(ResolvedHand(handNumber: index + 1, bet: hand.bet, outcome: .push, payout: pushBack))
            } else {
                resolved.append(ResolvedHand(handNumber: index + 1, bet: hand.bet, outcome: .loss, payout: 0))
            }
        }

        credit(payout)
        results = resolved
        roundMessage = insuranceBet > 0 ? "Dealer blackjack · insurance paid" : "Dealer blackjack"
        endRound(insuranceReturn: insuranceReturn)
    }

    private func settleRound() {
        let dealerScore = dealerHand.score.total
        let dealerBust = dealerHand.isBust
        var payout = 0
        var resolved: [ResolvedHand] = []

        for (index, hand) in playerHands.enumerated() {
            let outcome: HandOutcome
            let handPayout: Int

            if hand.isBust {
                outcome = .bust
                handPayout = 0
            } else if hand.isNaturalBlackjack {
                outcome = .blackjack
                handPayout = rules.blackjackReturn(for: hand.bet)
            } else if dealerBust || hand.score.total > dealerScore {
                outcome = .win
                handPayout = hand.bet * 2
            } else if hand.score.total == dealerScore {
                outcome = .push
                handPayout = hand.bet
            } else {
                outcome = .loss
                handPayout = 0
            }

            payout += handPayout
            resolved.append(ResolvedHand(handNumber: index + 1, bet: hand.bet, outcome: outcome, payout: handPayout))
        }

        credit(payout)
        results = resolved
        roundMessage = summaryTitle(for: resolved)
        endRound()
    }

    private func endRound(insuranceReturn: Int = 0) {
        isDealing = false
        isOfferingInsurance = false
        insuranceDraft = 0
        withAnimation(.snappy(duration: 0.35)) {
            phase = .roundOver
        }

        let outcome = roundOutcome(for: results)
        let staked = results.reduce(0) { $0 + $1.bet } + insuranceBet
        let returned = results.reduce(0) { $0 + $1.payout } + insuranceReturn
        let net = returned - staked

        handsThisSession += 1
        sessionNet += net

        FeedbackManager.play(for: outcome)
        SoundManager.shared.play(SoundEffect(outcome: outcome))
        triggerTableEffect(outcome: outcome, originalBet: player.lastBet, netProfit: net)

        let discovered = gameRoom?.recordHand(
            outcome: outcome,
            isFractured: isFractured,
            net: net,
            floor: preset.name
        ) ?? []
        lastSummary = RoundSummary(
            outcome: outcome,
            title: summaryTitle(for: results),
            net: net,
            bet: staked,
            playerTotal: playerHands.first?.score.total ?? 0,
            dealerTotal: dealerHand.score.total,
            discovery: discovered.first
        )

        if let discovery = discovered.first {
            say("A new \(discovery.category.title.lowercased().dropLast()) is on the shelf", icon: "sparkles")
        }

        sweepBetOffTable(for: outcome)
        resolveRoundCompletion()
    }

    /// Pushes the bet across the felt to whoever won it, then takes it off the
    /// table. A push counts as the player's — the stake comes back either way.
    private func sweepBetOffTable(for outcome: RoundOutcome) {
        guard !betStack.isEmpty else { return }
        let winner: ChipSweep = (outcome == .loss || outcome == .bust) ? .toDealer : .toPlayer

        sweepTask?.cancel()
        sweepTask = Task { [weak self] in
            // A beat first, so the result registers before the chips move.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeIn(duration: 0.5)) {
                    self?.chipSweep = winner
                }
            }

            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                // The pile is already invisible by now, so this just tidies up.
                self?.betStack = []
                self?.chipSweep = nil
            }
        }
    }

    private func cancelBetSweep() {
        sweepTask?.cancel()
        sweepTask = nil
        chipSweep = nil
    }

    private func summaryTitle(for resolved: [ResolvedHand]) -> String {
        guard resolved.count == 1, let result = resolved.first else {
            return "Round complete"
        }
        return result.outcome.title
    }

    private func triggerTableEffect(outcome: RoundOutcome, originalBet: Int, netProfit: Int) {
        let effect: TableEffect?
        switch outcome {
        case .blackjack:
            effect = .blackjackSparkle
        case .bust:
            effect = .bustCrack
        case .win where netProfit >= originalBet * 2:
            effect = .bigWinPulse
        default:
            effect = nil
        }

        guard let effect else { return }
        activeTableEffect = effect

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if activeTableEffect == effect {
                activeTableEffect = nil
            }
        }
    }

    private func resetForBetting(currentBet: Int) {
        cancelBetSweep()
        player.currentBet = currentBet
        betStack = []
        playerHands = []
        dealerHand = Hand()
        activeHandIndex = 0
        dealerHoleRevealed = false
        insuranceBet = 0
        insuranceDraft = 0
        isOfferingInsurance = false
        isDealing = false
        results = []

        if currentBet == 0 {
            roundMessage = "Place your bet"
        } else if currentBet >= rules.minimumBet {
            roundMessage = "Ready when you are"
        } else {
            roundMessage = "Minimum bet \(rules.minimumBet.money)"
        }

        withAnimation(.snappy(duration: 0.35)) {
            phase = .betting
        }
    }

    /// Rebuilds a chip column that adds up to `amount` using the table's own denominations.
    private func rebuildStack(for amount: Int) {
        var remaining = amount
        var rebuilt: [PlacedChip] = []
        for denomination in chipDenominations.sorted(by: { $0.value > $1.value }) {
            while remaining >= denomination.value {
                remaining -= denomination.value
                rebuilt.append(
                    PlacedChip(
                        value: denomination.value,
                        label: denomination.label,
                        color: denomination.color,
                        index: rebuilt.count
                    )
                )
            }
        }
        betStack = rebuilt
    }

    private func resolveRoundCompletion() {
        refreshFloorUnlocks()

        guard !isFractured, preset.id != TablePreset.casinoFloor.id else { return }
        guard player.balance < rules.minimumBet else { return }

        let name = preset.name
        let minimum = rules.minimumBet
        enterCasinoFloorDirectly()
        ejectMessage = "Escorted out of \(name) — balance fell below the \(minimum.money) minimum"
    }

    private func prepareShoeForRoundIfNeeded() {
        let low = shoe.remainingCount <= rules.reshuffleAtRemaining
        guard shoe.needsReshuffle || low else { return }
        shoe = Shoe(deckCount: rules.numberOfDecks)
        SoundManager.shared.play(.shuffle)
    }

    private func revealDealerHole() {
        let shouldPlayFlip = !dealerHoleRevealed
        withAnimation(.smooth(duration: 0.45)) {
            dealerHoleRevealed = true
        }
        playDealerHoleFlipIfNeeded(shouldPlay: shouldPlayFlip)
    }

    private func playDealerHoleFlipIfNeeded(shouldPlay: Bool) {
        guard shouldPlay else { return }
        SoundManager.shared.play(.cardFlip)
    }

    private func roundOutcome(for resolved: [ResolvedHand]) -> RoundOutcome {
        let outcomes = resolved.map(\.outcome)

        if outcomes.contains(.blackjack) { return .blackjack }
        if outcomes.contains(.win) { return .win }
        if !outcomes.isEmpty && outcomes.allSatisfy({ $0 == .push }) { return .push }
        if outcomes.contains(.bust) { return .bust }
        return .loss
    }

    private func dealCard(to target: DealTarget) async {
        try? await Task.sleep(nanoseconds: 160_000_000)
        var activeShoe = shoe
        let card = activeShoe.deal()
        shoe = activeShoe

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            switch target {
            case .dealer:
                dealerHand.add(card)
            case .player(let index):
                guard playerHands.indices.contains(index) else { return }
                playerHands[index].add(card)
                gameRoom?.recordDealtCard(card, isFractured: isFractured)
            }
        }

        FeedbackManager.cardSlide()
        SoundManager.shared.play(.cardDeal)
    }

    // MARK: - Money

    private func debit(_ amount: Int) {
        guard amount > 0 else { return }
        if isFractured {
            sessionStack -= amount
        } else {
            player.balance -= amount
            persistBalance()
        }
    }

    private func credit(_ amount: Int) {
        guard amount > 0 else { return }
        if isFractured {
            sessionStack += amount
        } else {
            player.balance += amount
            persistBalance()
        }
    }

    // MARK: - Multiplayer money

    /// §6 — a shared table plays off the same balance as a solo one, but the balance
    /// itself never crosses the wire. The stake leaves here when the bet is sent and
    /// the payout comes back here when the host reports the result. A multiplayer
    /// table always plays off the bankroll, never the Fractured session stack.
    @discardableResult
    func stakeForMultiplayer(_ amount: Int) -> Bool {
        guard amount > 0, player.balance >= amount else { return false }
        player.balance -= amount
        unsettledMultiplayerStake += amount
        persistBalance()
        SoundManager.shared.play(.chipBet)
        return true
    }

    func applyMultiplayerResult(payout: Int) {
        unsettledMultiplayerStake = 0
        guard payout > 0 else { return }
        player.balance += payout
        persistBalance()
    }

    /// Returns every stake that has left this device without a settlement. This
    /// covers leaving a table or losing the host before a result can arrive.
    func refundUnsettledMultiplayerStake() {
        guard unsettledMultiplayerStake > 0 else { return }
        player.balance += unsettledMultiplayerStake
        unsettledMultiplayerStake = 0
        persistBalance()
    }

    /// Writes the balance and re-checks whether a grant should be counting down.
    private func persistBalance() {
        defaults.set(player.balance, forKey: balanceKey)
        updateBankruptGrant()
    }

    // MARK: - Bankrupt grant (§5)

    private var grantInterval: TimeInterval {
        TimeInterval(rules.bankruptGrantIntervalMinutes * 60)
    }

    /// At $0 a small amount quietly arrives on a repeating timer. No popup and no
    /// prompt — but the table shows how long the wait is, so it is not a mystery.
    ///
    /// Called on every balance change and every table change, and safe to call
    /// repeatedly: an in-flight countdown is left alone.
    func updateBankruptGrant() {
        // Fractured runs off a session stack, so the balance is not what is empty.
        guard !isFractured, player.balance <= 0 else {
            grantTask?.cancel()
            grantTask = nil
            if grantDeadline != nil { grantDeadline = nil }
            return
        }

        guard grantTask == nil else { return }

        grantDeadline = Date().addingTimeInterval(grantInterval)
        grantTask = Task { [weak self] in
            while !Task.isCancelled {
                let wait = await MainActor.run { self?.grantDeadline?.timeIntervalSinceNow ?? 0 }
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }

                let stillBroke = await MainActor.run { self?.deliverBankruptGrant() ?? false }
                guard stillBroke else { return }
            }
        }
    }

    /// Pays one grant. Reports whether the player is still at zero afterwards, so
    /// the countdown knows whether to start over.
    private func deliverBankruptGrant() -> Bool {
        player.balance += rules.bankruptGrantAmount
        defaults.set(player.balance, forKey: balanceKey)
        say("\(rules.bankruptGrantAmount.money) arrived", icon: "banknote")

        guard player.balance <= 0 else {
            grantDeadline = nil
            grantTask = nil
            return false
        }

        grantDeadline = Date().addingTimeInterval(grantInterval)
        return true
    }

    /// §5 — on a next-day launch at $0, another grant is waiting.
    private func applyDailyRefillIfNeeded(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        let lastLaunch = defaults.object(forKey: lastLaunchDayKey) as? Date
        defaults.set(today, forKey: lastLaunchDayKey)

        guard let lastLaunch, Calendar.current.startOfDay(for: lastLaunch) < today else { return }
        guard player.balance <= 0 else { return }
        player.balance += GameConfig.casinoFloor.bankruptGrantAmount
        persistBalance()
    }
}

/// Which way a settled bet leaves the felt.
enum ChipSweep: Equatable {
    case toPlayer
    case toDealer

    /// How far the pile travels before it has faded out. Short — this is a shove
    /// across the felt, not a journey.
    var travel: CGFloat {
        switch self {
        case .toPlayer: 150
        case .toDealer: -170
        }
    }
}

/// One chip sitting on the felt, with the toss it arrived on baked in.
struct PlacedChip: Identifiable, Equatable {
    let id = UUID()
    let value: Int
    let label: String
    let color: Color
    let index: Int

    /// Chips are tossed in from alternating sides so the pile does not fill from
    /// one direction.
    var fromX: CGFloat { index.isMultiple(of: 2) ? -96 : 96 }

    /// Chips land flat but never square-on.
    var rotation: Double { (Self.noise(index, salt: 3) - 0.5) * 70 }

    /// Where this chip settles, relative to the middle of the pile.
    ///
    /// Chips shoved together on felt spread outward far more than they stack
    /// upward, so the spread does the work and the lift barely moves — a pile,
    /// not a tower.
    ///
    /// Angles step by the golden angle, which is what stops chips landing on top
    /// of each other however many there are; the jitter keeps it from looking
    /// like a sunflower.
    var pileOffset: CGSize {
        let angle = Double(index) * 2.399_963 + (Self.noise(index, salt: 7) - 0.5) * 0.8
        let spread = 11.5 * Double(index).squareRoot() * (0.85 + 0.3 * Self.noise(index, salt: 11))
        let distance = min(40, spread)

        return CGSize(
            width: distance * cos(angle),
            // Squashed vertically because the felt is seen at an angle, plus a
            // little lift for the chips that landed last.
            height: distance * sin(angle) * 0.55 - min(10, 1.8 * Double(index).squareRoot())
        )
    }

    /// A stable hash, so a chip keeps the spot it landed in through every redraw.
    private static func noise(_ value: Int, salt: Int) -> Double {
        var bits = UInt64(bitPattern: Int64(value &* 2_654_435_761 &+ salt &* 40_503))
        bits ^= bits >> 33
        bits = bits &* 0xFF51_AFD7_ED55_8CCD
        bits ^= bits >> 33
        return Double(bits % 10_000) / 10_000
    }
}

private enum DealTarget {
    case dealer
    case player(index: Int)
}
