import Foundation

/// The shared table's card logic, run only by the host.
///
/// One authoritative peer rather than agreement between four: the host owns the
/// shoe and the dealer hand, everyone else sends intents and is told what happened.
/// Rules come from `GameConfig` like everywhere else — this deals, it does not
/// decide how blackjack works.
@MainActor
final class MultiplayerDealer {
    private(set) var shoe: Shoe
    private(set) var dealerHand = Hand()
    private(set) var hands: [String: Hand] = [:]
    private(set) var holeHidden = true

    let rules: GameConfig

    init(rules: GameConfig = .casinoFloor) {
        self.rules = rules
        shoe = Shoe(deckCount: rules.numberOfDecks)
    }

    var dealerScore: Int { dealerHand.score.total }

    func hand(for seat: String) -> Hand {
        hands[seat] ?? Hand()
    }

    /// Fresh hands for whoever is actually in this round.
    func startRound(seats: [String], bets: [String: Int]) {
        if shoe.needsReshuffle || shoe.remainingCount <= rules.reshuffleAtRemaining {
            shoe = Shoe(deckCount: rules.numberOfDecks)
        }

        dealerHand = Hand()
        holeHidden = true
        hands = [:]
        for seat in seats {
            hands[seat] = Hand(bet: bets[seat] ?? 0)
        }

        // Two rounds of the table, dealer last, the way it is dealt in person.
        for _ in 0..<2 {
            for seat in seats {
                hands[seat]?.add(draw())
            }
            dealerHand.add(draw())
        }
    }

    func hit(_ seat: String) {
        hands[seat]?.add(draw())
    }

    /// Doubles the stake and takes exactly one more card.
    func double(_ seat: String) {
        guard var hand = hands[seat] else { return }
        hand.bet *= 2
        hand.add(draw())
        hand.isStanding = true
        hands[seat] = hand
    }

    func stand(_ seat: String) {
        hands[seat]?.isStanding = true
    }

    func isFinished(_ seat: String) -> Bool {
        guard let hand = hands[seat] else { return true }
        return hand.isStanding || hand.isBust || hand.score.total >= 21
    }

    func status(for seat: String) -> SeatStatus {
        guard let hand = hands[seat], !hand.cards.isEmpty else { return .waiting }
        if hand.isBust { return .bust }
        if hand.isNaturalBlackjack { return .blackjack }
        return isFinished(seat) ? .done : .thinking
    }

    /// Plays the dealer out. Everyone busting still reveals the hole card — the
    /// table should always see how it would have gone.
    func playDealer() {
        holeHidden = false
        while shouldDealerHit {
            dealerHand.add(draw())
        }
    }

    private var shouldDealerHit: Bool {
        let score = dealerHand.score
        if score.total <= 16 { return true }
        return score.total == 17 && score.isSoft && rules.dealerHitsSoft17
    }

    /// What each seat gets back, stake included. Applied by each player against
    /// their own local balance — §6 keeps balances off the wire.
    func settle() -> [String: (outcome: HandOutcome, payout: Int)] {
        let dealerBust = dealerHand.isBust
        let dealerTotal = dealerHand.score.total
        var results: [String: (HandOutcome, Int)] = [:]

        for (seat, hand) in hands where !hand.cards.isEmpty {
            let outcome: HandOutcome
            let payout: Int

            if hand.isBust {
                outcome = .bust
                payout = 0
            } else if hand.isNaturalBlackjack {
                outcome = .blackjack
                payout = rules.blackjackReturn(for: hand.bet)
            } else if dealerBust || hand.score.total > dealerTotal {
                outcome = .win
                payout = hand.bet * 2
            } else if hand.score.total == dealerTotal {
                outcome = .push
                payout = rules.pushReturn(for: hand.bet)
            } else {
                outcome = .loss
                payout = 0
            }

            results[seat] = (outcome, payout)
        }

        return results
    }

    private func draw() -> Card {
        var working = shoe
        let card = working.deal()
        shoe = working
        return card
    }
}
