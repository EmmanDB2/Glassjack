import SwiftUI

enum MPRole: Equatable {
    case idle
    case hosting
    case joining
}

enum MPConnection: Equatable {
    case offline
    case searching
    case connected
    case failed(String)
}

/// What the local player owes or is owed for the round just finished. Applied
/// against the local balance by the table screen — §6 keeps balances off the wire.
struct MPSettlement: Equatable {
    let roundID: Int
    let outcome: HandOutcome
    let payout: Int
}

/// §6 — up to four players on separate devices sharing one dealer.
///
/// The host is authoritative: it owns the shoe, runs the turn order and rebroadcasts
/// the table after every change. Guests send intents and render what comes back.
/// That avoids any need for the four devices to agree with each other.
@MainActor
final class MultiplayerSession: ObservableObject {
    static let maxSeats = 4

    @Published private(set) var role: MPRole = .idle
    @Published private(set) var connection: MPConnection = .offline
    @Published private(set) var snapshot = TableSnapshot()
    @Published private(set) var settlement: MPSettlement?

    /// This device's identity for the whole session, independent of display name.
    let playerID = UUID().uuidString

    private var transport: MultiplayerTransport?
    private var dealer: MultiplayerDealer?
    private var displayName = "Player"

    // Host-only state
    private struct Seat {
        let id: String
        var peer: String?
        var name: String
        var bet = 0
        var hasBet = false
        var isSpectating = false
        let isHost: Bool
    }

    private var seats: [Seat] = []
    private var settledRound = -1

    // MARK: - Lobby

    var isHost: Bool { role == .hosting }

    var mySeatID: String { playerID }

    var mySeat: SeatSnapshot? { snapshot.seat(playerID) }

    var otherSeats: [SeatSnapshot] {
        snapshot.seats.filter { $0.id != playerID }
    }

    var isMyTurn: Bool {
        snapshot.activeSeatID == playerID
    }

    var openSeats: Int {
        max(0, Self.maxSeats - snapshot.seats.count)
    }

    var canStart: Bool {
        isHost && snapshot.phase == .lobby && snapshot.seats.count >= 2
    }

    func host(as name: String) {
        stop()
        displayName = name
        role = .hosting
        connection = .searching

        let code = Self.makeRoomCode()
        let dealer = MultiplayerDealer()
        self.dealer = dealer

        seats = [Seat(id: playerID, peer: nil, name: name, isHost: true)]
        settledRound = -1

        snapshot = TableSnapshot(
            phase: .lobby,
            roomCode: code,
            minimumBet: dealer.rules.minimumBet,
            maximumBet: dealer.rules.maximumBet
        )

        let transport = MultipeerTransport()
        transport.delegate = self
        transport.startHosting(roomCode: code, displayName: name)
        self.transport = transport

        rebuild()
    }

    func join(code: String, as name: String) {
        stop()
        displayName = name
        role = .joining
        connection = .searching
        snapshot = TableSnapshot(roomCode: code.uppercased())

        let transport = MultipeerTransport()
        transport.delegate = self
        transport.startJoining(roomCode: code.uppercased(), displayName: name)
        self.transport = transport
    }

    func stop() {
        if role == .joining, connection == .connected {
            transport?.send(.leave, to: nil)
        }
        transport?.stop()
        transport = nil
        dealer = nil
        seats = []
        role = .idle
        connection = .offline
        snapshot = TableSnapshot()
        settlement = nil
    }

    /// §6 — the code leaves the air the moment the game starts, freeing it for reuse.
    func startGame() {
        guard canStart else { return }
        snapshot.roomCode = ""
        beginBetting()
    }

    func clearSettlement() {
        settlement = nil
    }

    // MARK: - Player intents

    func placeBet(_ amount: Int) {
        guard snapshot.phase == .betting else { return }
        if isHost {
            apply(.placeBet(amount), from: playerID)
        } else {
            transport?.send(.placeBet(amount), to: nil)
        }
    }

    func act(_ action: SeatAction) {
        guard isMyTurn else { return }
        if isHost {
            apply(.act(action), from: playerID)
        } else {
            transport?.send(.act(action), to: nil)
        }
    }

    /// Host only: move the table on from the summary.
    func nextRound() {
        guard isHost, snapshot.phase == .summary else { return }
        beginBetting()
    }

    static func makeRoomCode() -> String {
        // A–Z and 0–9 minus the characters people misread out loud.
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }

    // MARK: - Host: the round

    private func beginBetting() {
        guard isHost else { return }
        snapshot.roundID += 1
        for index in seats.indices {
            seats[index].bet = 0
            seats[index].hasBet = false
            seats[index].isSpectating = false
        }
        snapshot.phase = .betting
        snapshot.activeSeatID = nil
        snapshot.dealerCards = []
        snapshot.dealerTotal = nil
        snapshot.dealerHoleHidden = true
        rebuild()
    }

    private func dealIfEveryoneHasBet() {
        guard isHost, snapshot.phase == .betting else { return }
        // §6: all players bet simultaneously, then the dealer deals to all.
        guard seats.allSatisfy({ $0.hasBet || $0.isSpectating }) else { return }

        let playing = seats.filter { !$0.isSpectating }.map(\.id)
        guard !playing.isEmpty else { return }

        var bets: [String: Int] = [:]
        for seat in seats where !seat.isSpectating {
            bets[seat.id] = seat.bet
        }

        dealer?.startRound(seats: playing, bets: bets)
        snapshot.phase = .playing
        advanceTurn(startingOver: true)
    }

    /// Players act in join order (§6), skipping anyone already resolved.
    private func advanceTurn(startingOver: Bool = false) {
        guard isHost, let dealer else { return }

        let order = seats.filter { !$0.isSpectating }.map(\.id)
        let startIndex: Int
        if startingOver {
            startIndex = 0
        } else if let current = snapshot.activeSeatID, let index = order.firstIndex(of: current) {
            startIndex = index + 1
        } else {
            startIndex = order.count
        }

        for index in startIndex..<order.count where !dealer.isFinished(order[index]) {
            snapshot.activeSeatID = order[index]
            rebuild()
            return
        }

        snapshot.activeSeatID = nil
        finishRound()
    }

    private func finishRound() {
        guard isHost, let dealer else { return }
        snapshot.phase = .dealerTurn
        rebuild()

        Task { @MainActor in
            // A beat so the table sees the hole card turn before the dealer draws.
            try? await Task.sleep(nanoseconds: 700_000_000)
            dealer.playDealer()
            snapshot.dealerHoleHidden = false
            snapshot.phase = .summary
            rebuild()
        }
    }

    // MARK: - Host: applying intents

    private func apply(_ message: MPMessage, from peerOrSeat: String) {
        guard isHost else { return }

        switch message {
        case let .join(playerID, name):
            addSeat(playerID: playerID, peer: peerOrSeat, name: name)

        case let .placeBet(amount):
            guard let index = seatIndex(forSeatOrPeer: peerOrSeat),
                  snapshot.phase == .betting else { return }
            if amount <= 0 {
                seats[index].isSpectating = true
                seats[index].bet = 0
            } else {
                seats[index].bet = amount
            }
            seats[index].hasBet = true
            rebuild()
            dealIfEveryoneHasBet()

        case let .act(action):
            guard let dealer,
                  let index = seatIndex(forSeatOrPeer: peerOrSeat),
                  snapshot.activeSeatID == seats[index].id else { return }
            let seatID = seats[index].id

            switch action {
            case .hit: dealer.hit(seatID)
            case .stand: dealer.stand(seatID)
            case .double: dealer.double(seatID)
            }

            if dealer.isFinished(seatID) {
                advanceTurn()
            } else {
                rebuild()
            }

        case .leave:
            removeSeat(peer: peerOrSeat)

        case .snapshot, .removed:
            break
        }
    }

    private func addSeat(playerID: String, peer: String, name: String) {
        guard !seats.contains(where: { $0.id == playerID }) else { return }
        guard seats.count < Self.maxSeats, snapshot.phase == .lobby else {
            transport?.send(.removed(reason: "That table is full"), to: peer)
            return
        }
        seats.append(Seat(id: playerID, peer: peer, name: name, isHost: false))
        SoundManager.shared.play(.chipBet)
        rebuild()
    }

    private func removeSeat(peer: String) {
        guard let index = seats.firstIndex(where: { $0.peer == peer }) else { return }
        let leaving = seats[index].id
        seats.remove(at: index)

        if snapshot.activeSeatID == leaving {
            advanceTurn()
        } else {
            rebuild()
        }
    }

    private func seatIndex(forSeatOrPeer value: String) -> Int? {
        seats.firstIndex { $0.id == value || $0.peer == value }
    }

    // MARK: - Host: publishing

    /// Rebuilds the table and sends each device its own redacted view.
    private func rebuild() {
        guard isHost, let dealer else { return }

        snapshot.shoeRemaining = dealer.shoe.remainingCount
        snapshot.dealerCards = dealer.dealerHand.cards
        snapshot.dealerHoleHidden = dealer.holeHidden && snapshot.phase != .summary
        snapshot.dealerTotal = snapshot.phase == .summary || !dealer.holeHidden
            ? dealer.dealerScore
            : nil

        let results = snapshot.phase == .summary ? dealer.settle() : [:]

        snapshot.seats = seats.map { seat in
            let hand = dealer.hand(for: seat.id)
            let result = results[seat.id]
            return SeatSnapshot(
                id: seat.id,
                name: seat.name,
                bet: hand.cards.isEmpty ? seat.bet : hand.bet,
                status: seatStatus(seat, dealer: dealer),
                isHost: seat.isHost,
                cards: hand.cards,
                total: hand.cards.isEmpty ? nil : hand.score.total,
                outcome: result?.outcome,
                payout: result?.payout
            )
        }

        // Everyone gets the same table, but only their own cards. Every redaction is
        // cut from this one full copy — redacting `snapshot` in place first would
        // strip the guests' cards before their own copies were made.
        let full = snapshot

        for seat in seats {
            guard let peer = seat.peer else { continue }
            transport?.send(.snapshot(redacted(full, for: seat.id)), to: peer)
        }
        applyLocally(redacted(full, for: playerID))
    }

    private func seatStatus(_ seat: Seat, dealer: MultiplayerDealer) -> SeatStatus {
        if seat.isSpectating { return .spectating }
        switch snapshot.phase {
        case .lobby: return .waiting
        case .betting: return seat.hasBet ? .done : .betting
        default: return dealer.status(for: seat.id)
        }
    }

    /// §6 — nobody sees another player's hand value until the round resolves, so the
    /// cards are stripped from the wire rather than merely left undrawn.
    private func redacted(_ source: TableSnapshot, for viewer: String) -> TableSnapshot {
        guard source.phase != .summary else { return source }

        var copy = source
        copy.seats = copy.seats.map { seat in
            guard seat.id != viewer else { return seat }
            var hidden = seat
            hidden.cards = []
            hidden.total = nil
            hidden.outcome = nil
            hidden.payout = nil
            return hidden
        }
        return copy
    }

    // MARK: - Both sides

    private func applyLocally(_ incoming: TableSnapshot) {
        snapshot = incoming
        noteSettlementIfNeeded()
    }

    /// Fires once per round, for this device's own result only.
    private func noteSettlementIfNeeded() {
        guard snapshot.phase == .summary,
              settledRound != snapshot.roundID,
              let seat = snapshot.seat(playerID),
              let outcome = seat.outcome,
              let payout = seat.payout else { return }

        settledRound = snapshot.roundID
        settlement = MPSettlement(roundID: snapshot.roundID, outcome: outcome, payout: payout)
        FeedbackManager.play(for: outcome.roundOutcome)
        SoundManager.shared.play(SoundEffect(outcome: outcome.roundOutcome))
    }
}

// MARK: - Transport

extension MultiplayerSession: MultiplayerTransportDelegate {
    func transportDidConnect(peer: String) {
        connection = .connected

        if role == .joining {
            // Introduce ourselves; the host allocates the seat.
            transport?.send(.join(playerID: playerID, name: displayName), to: peer)
        }
    }

    func transportDidDisconnect(peer: String) {
        if isHost {
            removeSeat(peer: peer)
        } else {
            connection = .failed("The host left the table")
        }
    }

    func transportDidReceive(_ message: MPMessage, from peer: String) {
        switch message {
        case let .snapshot(incoming):
            guard !isHost else { return }
            applyLocally(incoming)

        case let .removed(reason):
            connection = .failed(reason)
            transport?.stop()

        default:
            apply(message, from: peer)
        }
    }

    func transportDidFail(_ reason: String) {
        connection = .failed(reason)
    }
}
