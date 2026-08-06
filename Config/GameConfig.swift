import Foundation

/// A card type that only exists inside Fractured Mode shoes.
struct WildCardDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
}

/// A stackable rule change. Fractured Mode lets the player toggle these before a session.
struct RuleModifier: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    var isEnabled: Bool
}

/// A pre-authored Fractured Mode win condition.
struct ChallengeScenario: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let stack: Int
}

/// Every gameplay rule in one place. Swapping this object changes how the game plays —
/// no engine code knows a literal payout, limit or deck count.
struct GameConfig: Equatable {
    // Payouts
    var blackjackPayout: Double = 1.5
    var insurancePayout: Double = 2.0
    var pushPayout: Double = 1.0

    // Dealer rules
    var dealerHitsSoft17 = true
    var dealerPeeksForBlackjack = true

    // Player options
    var allowSplit = true
    var allowDouble = true
    var allowSurrender = false
    var allowInsurance = true
    var maxSplitHands = 2

    // Shoe
    var numberOfDecks = 6
    var reshuffleAtRemaining = 52

    // Economy
    var startingBalance = 1_000
    var bankruptGrantAmount = 100
    var bankruptGrantIntervalMinutes = 20
    var minimumBet = 10
    var maximumBet = 2_500
    var entryFee = 0

    /// When true the table runs off a session-only stack and never touches the player's balance.
    var usesSessionStack = false
    var sessionStack = 0

    // Fractured Mode
    var wildCards: [WildCardDefinition] = []
    var modifiers: [RuleModifier] = []
    var challenge: ChallengeScenario?

    var totalShoeCards: Int {
        numberOfDecks * 52
    }

    /// Total returned to the player for a natural blackjack, stake included.
    func blackjackReturn(for bet: Int) -> Int {
        bet + Int((Double(bet) * blackjackPayout).rounded(.down))
    }

    /// Total returned for a winning insurance bet, stake included.
    func insuranceReturn(for bet: Int) -> Int {
        bet + Int((Double(bet) * insurancePayout).rounded(.down))
    }

    func pushReturn(for bet: Int) -> Int {
        Int((Double(bet) * pushPayout).rounded(.down))
    }
}

extension GameConfig {
    static let casinoFloor = GameConfig()

    static let highRoller = GameConfig(
        dealerHitsSoft17: true,
        numberOfDecks: 8,
        minimumBet: 500,
        maximumBet: 10_000,
        entryFee: 500
    )

    static let midnight = GameConfig(
        dealerHitsSoft17: false,
        numberOfDecks: 6,
        minimumBet: 25,
        maximumBet: 5_000
    )

    static let morningCafe = GameConfig(
        blackjackPayout: 1.5,
        dealerHitsSoft17: false,
        numberOfDecks: 2,
        minimumBet: 5,
        maximumBet: 500
    )

    static let fractured = GameConfig(
        dealerHitsSoft17: true,
        dealerPeeksForBlackjack: false,
        allowInsurance: false,
        numberOfDecks: 4,
        minimumBet: 10,
        maximumBet: 2_000,
        usesSessionStack: true,
        sessionStack: 500,
        wildCards: WildCardDefinition.catalog,
        modifiers: RuleModifier.catalog,
        challenge: ChallengeScenario.catalog.first
    )
}

extension WildCardDefinition {
    /// §8 lists the final wild card set as TBD; these are the framework's seed entries.
    static let catalog: [WildCardDefinition] = [
        WildCardDefinition(id: "mirror", name: "Mirror", detail: "Copies the value of the card before it"),
        WildCardDefinition(id: "drift", name: "Drift", detail: "Worth 1 or 11, your call, once per hand"),
        WildCardDefinition(id: "hollow", name: "Hollow", detail: "Worth nothing and does not count toward a bust")
    ]
}

extension RuleModifier {
    static let catalog: [RuleModifier] = [
        RuleModifier(
            id: "soft21",
            name: "Soft 21 pays double",
            detail: "An ace in hand at 21",
            isEnabled: true
        ),
        RuleModifier(
            id: "openDealer",
            name: "Dealer shows both",
            detail: "No hole card at all",
            isEnabled: false
        ),
        RuleModifier(
            id: "shiftingTarget",
            name: "Shifting target",
            detail: "21 moves by ±1 each round",
            isEnabled: true
        )
    ]
}

extension ChallengeScenario {
    static let catalog: [ChallengeScenario] = [
        ChallengeScenario(
            id: "climb",
            title: "Reach $2,000 in nine hands",
            detail: "Every hand counts. Bust twice and it ends.",
            stack: 500
        ),
        ChallengeScenario(
            id: "hold",
            title: "Finish twelve hands above $500",
            detail: "Slow and steady. Dips are allowed, the last hand is not.",
            stack: 500
        )
    ]
}
