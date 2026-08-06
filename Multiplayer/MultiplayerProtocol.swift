import Foundation

/// What a seat is doing right now. This is all the other players ever see of you
/// mid-round — §6 is explicit that the hand value stays private until it resolves.
enum SeatStatus: String, Codable, Equatable {
    case waiting
    case betting
    case thinking
    case done
    case bust
    case blackjack
    /// At $0 with no grant yet: still at the table, not in the hand.
    case spectating
}

/// Where the shared table is in the round.
enum MPPhase: String, Codable, Equatable {
    case lobby
    case betting
    case playing
    case dealerTurn
    case summary
}

enum SeatAction: String, Codable, Equatable {
    case hit
    case stand
    case double
}

/// One seat as the recipient is allowed to see it.
///
/// `cards`, `total` and the result fields are filled in only for the player's own
/// seat, or for everybody once the round has resolved. The host redacts per
/// recipient, so a hidden hand is genuinely absent from the wire rather than just
/// undrawn.
struct SeatSnapshot: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var bet: Int
    var status: SeatStatus
    var isHost: Bool
    var cards: [Card] = []
    var total: Int?
    var outcome: HandOutcome?
    var payout: Int?

    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

/// The whole shared table, rebuilt and rebroadcast by the host after every change.
/// Small enough at four seats that diffing would cost more than it saves.
struct TableSnapshot: Codable, Equatable {
    var phase: MPPhase = .lobby
    /// Bumped by the host each round, so every device settles exactly once.
    var roundID = 0
    /// Cleared the moment the game starts, freeing the code for reuse (§6).
    var roomCode: String = ""
    var seats: [SeatSnapshot] = []
    var dealerCards: [Card] = []
    var dealerHoleHidden = true
    var dealerTotal: Int?
    /// Whose turn it is. Players act in join order (§6).
    var activeSeatID: String?
    var shoeRemaining = 0
    var minimumBet = 10
    var maximumBet = 2_500

    func seat(_ id: String?) -> SeatSnapshot? {
        guard let id else { return nil }
        return seats.first { $0.id == id }
    }
}

/// Everything that crosses the wire. Guests send intents, the host sends truth.
enum MPMessage: Codable, Equatable {
    // Guest → host
    case join(playerID: String, name: String)
    case placeBet(Int)
    case act(SeatAction)
    case leave

    // Host → guest
    case snapshot(TableSnapshot)
    case removed(reason: String)
}

// MARK: - Transport

/// The seam between the game and whatever is carrying the bytes.
///
/// MultipeerConnectivity backs this today. A Firebase-backed implementation would
/// conform to the same protocol and nothing above this line would change.
@MainActor
protocol MultiplayerTransport: AnyObject {
    var delegate: MultiplayerTransportDelegate? { get set }

    /// Start advertising a table under this code.
    func startHosting(roomCode: String, displayName: String)
    /// Start looking for a table advertising this code.
    func startJoining(roomCode: String, displayName: String)
    /// `peer == nil` broadcasts to everyone connected.
    func send(_ message: MPMessage, to peer: String?)
    func stop()
}

@MainActor
protocol MultiplayerTransportDelegate: AnyObject {
    func transportDidConnect(peer: String)
    func transportDidDisconnect(peer: String)
    func transportDidReceive(_ message: MPMessage, from peer: String)
    func transportDidFail(_ reason: String)
}
