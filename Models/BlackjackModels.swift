import Foundation

enum GamePhase: String, Codable, Equatable {
    case betting
    case playerTurn
    case dealerTurn
    case roundOver
}

enum Suit: String, CaseIterable, Codable, Hashable {
    case spades
    case hearts
    case diamonds
    case clubs

    var glyph: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    var name: String {
        switch self {
        case .spades: "Spades"
        case .hearts: "Hearts"
        case .diamonds: "Diamonds"
        case .clubs: "Clubs"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }
}

enum Rank: Int, CaseIterable, Codable, Comparable, Hashable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbol: String {
        switch self {
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        case .ace: "A"
        default: String(rawValue)
        }
    }

    var name: String {
        switch self {
        case .two: "Two"
        case .three: "Three"
        case .four: "Four"
        case .five: "Five"
        case .six: "Six"
        case .seven: "Seven"
        case .eight: "Eight"
        case .nine: "Nine"
        case .ten: "Ten"
        case .jack: "Jack"
        case .queen: "Queen"
        case .king: "King"
        case .ace: "Ace"
        }
    }

    var blackjackValue: Int {
        switch self {
        case .jack, .queen, .king:
            10
        case .ace:
            11
        default:
            rawValue
        }
    }

    var pipCount: Int? {
        switch self {
        case .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten:
            rawValue
        case .jack, .queen, .king, .ace:
            nil
        }
    }

    var isTenValue: Bool {
        blackjackValue == 10
    }
}

struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    let rank: Rank
    let suit: Suit

    init(id: UUID = UUID(), rank: Rank, suit: Suit) {
        self.id = id
        self.rank = rank
        self.suit = suit
    }

    var accessibilityName: String {
        "\(rank.name) of \(suit.name)"
    }
}

struct HandScore: Equatable {
    let total: Int
    let isSoft: Bool
}

struct Hand: Identifiable, Codable, Hashable {
    let id: UUID
    var cards: [Card]
    var bet: Int
    var isStanding: Bool
    var isFromSplit: Bool

    init(
        id: UUID = UUID(),
        cards: [Card] = [],
        bet: Int = 0,
        isStanding: Bool = false,
        isFromSplit: Bool = false
    ) {
        self.id = id
        self.cards = cards
        self.bet = bet
        self.isStanding = isStanding
        self.isFromSplit = isFromSplit
    }

    var score: HandScore {
        var total = cards.reduce(0) { $0 + $1.rank.blackjackValue }
        var acesCountedAsEleven = cards.filter { $0.rank == .ace }.count

        while total > 21 && acesCountedAsEleven > 0 {
            total -= 10
            acesCountedAsEleven -= 1
        }

        return HandScore(total: total, isSoft: acesCountedAsEleven > 0)
    }

    var isBust: Bool {
        score.total > 21
    }

    var isNaturalBlackjack: Bool {
        cards.count == 2 && score.total == 21 && !isFromSplit
    }

    var canSplitByRank: Bool {
        cards.count == 2 && cards[0].rank == cards[1].rank
    }

    mutating func add(_ card: Card) {
        cards.append(card)
    }
}

struct Shoe {
    let deckCount: Int
    let totalCards: Int
    private(set) var cards: [Card]
    private(set) var cutCardPosition: Int
    private(set) var needsReshuffle: Bool

    var drawnCount: Int {
        totalCards - cards.count
    }

    /// Cards still in the shoe. Shown on the table as a real number — §5 says the
    /// count is deliberately visible.
    var remainingCount: Int {
        cards.count
    }

    var cardsRemainingFraction: Double {
        guard totalCards > 0 else { return 0 }
        return Double(cards.count) / Double(totalCards)
    }

    init(deckCount: Int = 6) {
        self.deckCount = max(1, deckCount)
        totalCards = self.deckCount * Suit.allCases.count * Rank.allCases.count
        cards = (0..<self.deckCount).flatMap { _ in
            Suit.allCases.flatMap { suit in
                Rank.allCases.map { rank in
                    Card(rank: rank, suit: suit)
                }
            }
        }
        cutCardPosition = Self.makeCutCardPosition(totalCards: totalCards)
        needsReshuffle = false
        fisherYatesShuffle()
    }

    mutating func deal() -> Card {
        if cards.isEmpty {
            self = Shoe(deckCount: deckCount)
        }

        let card = cards.removeLast()
        if drawnCount >= cutCardPosition {
            needsReshuffle = true
        }
        return card
    }

    private static func makeCutCardPosition(totalCards: Int) -> Int {
        let minRemaining = max(1, Int(ceil(Double(totalCards) * 0.19)))
        let maxRemaining = max(minRemaining, Int(ceil(Double(totalCards) * 0.24)))
        let remainingAtCut = Int.random(in: minRemaining...maxRemaining)
        return totalCards - remainingAtCut
    }

    private mutating func fisherYatesShuffle() {
        guard cards.count > 1 else { return }

        for index in stride(from: cards.count - 1, through: 1, by: -1) {
            let swapIndex = Int.random(in: 0...index)
            if swapIndex != index {
                cards.swapAt(index, swapIndex)
            }
        }
    }
}

struct Player: Codable, Equatable {
    var balance: Int
    var currentBet: Int
    var lastBet: Int
}

enum RoundOutcome: String, Codable, Equatable {
    case blackjack
    case win
    case push
    case loss
    case bust
}

enum TableEffect: Equatable {
    case blackjackSparkle
    case bustCrack
    case bigWinPulse
}

enum HighRollerExitReason {
    case voluntary
    case kickedOut
}

enum HandOutcome: String, Codable, Equatable {
    case blackjack
    case win
    case push
    case loss
    case bust

    var title: String {
        switch self {
        case .blackjack: "Blackjack"
        case .win: "Win"
        case .push: "Push"
        case .loss: "Loss"
        case .bust: "Bust"
        }
    }

    var roundOutcome: RoundOutcome {
        switch self {
        case .blackjack: .blackjack
        case .win: .win
        case .push: .push
        case .loss: .loss
        case .bust: .bust
        }
    }
}

struct ResolvedHand: Identifiable, Equatable {
    let id = UUID()
    let handNumber: Int
    let bet: Int
    let outcome: HandOutcome
    let payout: Int

    var summary: String {
        "Hand \(handNumber): \(outcome.title) · Bet $\(bet) · Paid $\(payout)"
    }
}
