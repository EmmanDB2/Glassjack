import SwiftUI

/// §6 — host a table or join one with a six-character code.
struct MultiplayerLobbyScreen: View {
    @ObservedObject var session: MultiplayerSession
    @ObservedObject var profile: ProfileStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme
    @State private var typedCode = ""
    @FocusState private var codeFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Play together", onBack: leave)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    switch session.role {
                    case .idle: chooser
                    case .hosting: hostingBody
                    case .joining: joiningBody
                    }

                    if case let .failed(reason) = session.connection {
                        problem(reason)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 12)
            }

            Spacer(minLength: 8)

            footer
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onChange(of: session.snapshot.phase) { _, phase in
            // The host starting the game pulls everyone through to the table.
            if phase != .lobby { screen = .multiplayerTable }
        }
    }

    private func leave() {
        session.stop()
        screen = .hub
    }

    // MARK: Choose

    private var chooser: some View {
        VStack(spacing: 12) {
            Text("Up to four of you, one dealer, everyone on the same Wi-Fi.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            DestinationRow(
                title: "Host a table",
                subtitle: "You deal. Share the code with the others.",
                systemImage: "person.2.badge.plus.fill",
                background: theme.accentTint,
                action: { session.host(as: profile.name) }
            )

            DestinationRow(
                title: "Join with a code",
                subtitle: "Type the six characters the host reads out",
                systemImage: "number",
                action: {
                    session.stop()
                    codeFocused = true
                    typedCode = ""
                    withAnimation { isEnteringCode = true }
                }
            )

            if isEnteringCode { codeEntry }

            // The GDD asks guests to type a display name; on iOS the profile already
            // has one, so the table borrows it rather than asking twice.
            Text("Playing as \(profile.name) · change it under You")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .padding(.top, 4)
        }
    }

    @State private var isEnteringCode = false

    private var codeEntry: some View {
        VStack(spacing: 12) {
            CodeBoxes(code: typedCode)
                .overlay {
                    // A real field behind the boxes, so the keyboard and paste work.
                    TextField("", text: $typedCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($codeFocused)
                        // Invisible but still hit-testable, so the boxes above are
                        // the only thing anyone sees.
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .onChange(of: typedCode) { _, new in
                            let cleaned = new.uppercased().filter { $0.isLetter || $0.isNumber }
                            let capped = String(cleaned.prefix(6))
                            if capped != new { typedCode = capped }
                        }
                }
                .onTapGesture { codeFocused = true }

            PrimaryAction(
                title: "Join",
                tint: theme.accentTint,
                isEnabled: typedCode.count == 6,
                height: 50
            ) {
                codeFocused = false
                session.join(code: typedCode, as: profile.name)
            }
        }
    }

    // MARK: Hosting

    private var hostingBody: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("YOUR ROOM CODE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1.4)
                    .foregroundStyle(theme.textMid)

                CodeBoxes(code: session.snapshot.roomCode)

                Text("The code disappears the moment you start.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }

            roster
        }
    }

    // MARK: Joining

    private var joiningBody: some View {
        VStack(spacing: 16) {
            if session.connection == .connected {
                roster

                Text("Waiting for the host to start.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Looking for table \(session.snapshot.roomCode)…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                    Text("Both devices need to be on the same Wi-Fi.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textMid)
                }
                .padding(.vertical, 30)
            }
        }
    }

    // MARK: Shared

    private var roster: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: "At the table", trailing: "\(session.snapshot.seats.count) of \(MultiplayerSession.maxSeats)")

            ForEach(session.snapshot.seats) { seat in
                SeatRow(seat: seat, isYou: seat.id == session.mySeatID)
            }

            ForEach(0..<session.openSeats, id: \.self) { index in
                EmptySeatRow(ordinal: Self.ordinal(session.snapshot.seats.count + index + 1))
            }
        }
    }

    private func problem(_ reason: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xD84A5A))
            Text(reason)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textDark)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(Color(hex: 0xD84A5A, opacity: 0.16), cornerRadius: 18)
    }

    @ViewBuilder
    private var footer: some View {
        if session.isHost {
            HStack(spacing: 12) {
                PrimaryAction(title: "Close table", height: 50) {
                    session.stop()
                }
                PrimaryAction(
                    title: "Start with \(session.snapshot.seats.count)",
                    tint: theme.accentTint,
                    isEnabled: session.canStart,
                    height: 50
                ) {
                    session.startGame()
                }
            }
        } else if session.role == .joining {
            PrimaryAction(title: "Leave", height: 50) {
                session.stop()
            }
        }
    }

    private static func ordinal(_ number: Int) -> String {
        switch number {
        case 2: "second"
        case 3: "third"
        case 4: "fourth"
        default: "next"
        }
    }
}

// MARK: - Rows

private struct CodeBoxes: View {
    @Environment(\.theme) private var theme

    let code: String

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<6, id: \.self) { index in
                let character = index < code.count
                    ? String(Array(code)[index])
                    : ""

                Text(character)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textDark)
                    .frame(width: 46, height: 58)
                    .glassSurface(character.isEmpty ? theme.glassTint : theme.pillTint, cornerRadius: 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(code.isEmpty ? "No code yet" : "Code \(code.map(String.init).joined(separator: " "))")
    }
}

private struct SeatRow: View {
    @Environment(\.theme) private var theme

    let seat: SeatSnapshot
    let isYou: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(seat.initial)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(theme.textDark)
                .frame(width: 30, height: 30)
                .background(Circle().fill(theme.pillTint))

            Text(isYou ? "\(seat.name) (you)" : seat.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textDark)
                .lineLimit(1)

            Spacer(minLength: 8)

            if seat.isHost {
                Text("host")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.textMid)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x34C759))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassSurface(theme.glassTint, cornerRadius: 18)
    }
}

private struct EmptySeatRow: View {
    @Environment(\.theme) private var theme

    let ordinal: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.silhouette)
                .frame(width: 30, height: 30)

            Text("Waiting for a \(ordinal)…")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textMid)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.dashColor, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
    }
}

// MARK: - Table

/// The GDD sketches a vertical side rail of nameplates. On a 393pt phone that rail
/// eats the card area, so the plates run across under the header instead — same
/// information, no squeeze.
struct MultiplayerTableScreen: View {
    @ObservedObject var session: MultiplayerSession
    @ObservedObject var game: BlackjackGame
    @ObservedObject var gameRoom: GameRoomStore
    @Binding var screen: AppScreen

    @Environment(\.theme) private var theme
    @State private var stagedBet = 0

    private var snapshot: TableSnapshot { session.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 12)

            namePlates
                .padding(.horizontal, 18)
                .padding(.top, 12)

            dealerArea
                .padding(.top, 16)

            Spacer(minLength: 0)

            playerArea
                .padding(.horizontal, 18)

            dock
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .onChange(of: snapshot.phase) { _, phase in
            if phase == .betting { stagedBet = 0 }
        }
        .onChange(of: session.settlement) { _, settlement in
            guard let settlement else { return }
            applySettlement(settlement)
        }
        .onChange(of: session.connection) { _, connection in
            if case .failed = connection { screen = .multiplayerLobby }
        }
    }

    // MARK: Local balance

    /// §6 — each player bets from their own balance and nothing about it leaves
    /// the device. The wire carries the stake, never the bankroll.
    private func applySettlement(_ settlement: MPSettlement) {
        game.applyMultiplayerResult(payout: settlement.payout)
        session.clearSettlement()

        // The session publishes exactly one settlement per round, so this counts once.
        if let discovery = gameRoom.recordMultiplayerRound().first {
            game.say("\(discovery.name) is on the shelf", icon: "sparkles")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            GlassPill(
                title: "Balance",
                amount: game.player.balance,
                systemImage: "banknote.fill",
                reactsToChanges: true
            )

            Spacer(minLength: 4)

            GlassIconButton(
                systemImage: "rectangle.portrait.and.arrow.right",
                accessibilityText: "Leave the table",
                action: {
                    session.stop()
                    screen = .hub
                }
            )
        }
    }

    private var namePlates: some View {
        HStack(spacing: 8) {
            ForEach(session.otherSeats) { seat in
                NamePlate(seat: seat, isActive: seat.id == snapshot.activeSeatID)
            }
        }
    }

    private var dealerArea: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                Text("Dealer")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textDark)

                Text(dealerTotalLabel)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassCapsule(theme.pillTint)

                Spacer(minLength: 0)

                Text("\(snapshot.shoeRemaining)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textMid)
            }
            .padding(.horizontal, 18)

            HandCardsView(
                cards: snapshot.dealerCards,
                hiddenIndex: snapshot.dealerHoleHidden ? 1 : nil,
                emptySymbol: "rectangle.stack.fill"
            )
        }
    }

    private var dealerTotalLabel: String {
        if let total = snapshot.dealerTotal { return "\(total)" }
        guard let first = snapshot.dealerCards.first else { return "0" }
        return "\(first.rank.blackjackValue)+"
    }

    private var playerArea: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                Text("You")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textDark)

                Text(myTotalLabel)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassCapsule(session.isMyTurn ? theme.accentTint : theme.glassTint)

                // Your own stake, since the nameplates only cover everyone else.
                if let bet = session.mySeat?.bet, bet > 0 {
                    Text(bet.money)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.textMid)
                }
            }

            HandCardsView(
                cards: session.mySeat?.cards ?? [],
                hiddenIndex: nil,
                emptySymbol: "person.fill"
            )

            Text(statusLine)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .frame(height: 20)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var myTotalLabel: String {
        guard let total = session.mySeat?.total else { return "0" }
        return "\(total)"
    }

    private var statusLine: String {
        switch snapshot.phase {
        case .lobby:
            return "Waiting for the table"
        case .betting:
            if session.mySeat?.status == .spectating { return "Sitting this one out" }
            return session.mySeat?.status == .done ? "Waiting on the others…" : "Place your bet"
        case .playing:
            if session.isMyTurn { return "Your move" }
            return "Waiting on \(snapshot.seat(snapshot.activeSeatID)?.name ?? "the table")…"
        case .dealerTurn:
            return "Dealer plays"
        case .summary:
            return session.mySeat?.outcome?.title ?? "Round complete"
        }
    }

    // MARK: Dock

    @ViewBuilder
    private var dock: some View {
        switch snapshot.phase {
        case .betting: bettingDock
        case .playing: actionDock
        case .summary: summaryDock
        default:
            Color.clear.frame(height: 54)
        }
    }

    private var bettingDock: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(game.chipDenominations) { denomination in
                    ChipButton(
                        denomination: denomination,
                        isEnabled: canStage(denomination.value),
                        action: { stagedBet += denomination.value }
                    )
                }
            }

            HStack(spacing: 12) {
                PrimaryAction(
                    title: stagedBet > 0 ? "Clear" : "Sit out",
                    systemImage: stagedBet > 0 ? "xmark.circle" : "pause.circle",
                    isEnabled: session.mySeat?.status != .done
                ) {
                    if stagedBet > 0 {
                        stagedBet = 0
                    } else {
                        session.placeBet(0)
                    }
                }

                PrimaryAction(
                    title: stagedBet > 0 ? "Bet \(stagedBet.money)" : "Bet",
                    systemImage: "checkmark",
                    tint: theme.accentTint,
                    isEnabled: stagedBet >= snapshot.minimumBet && session.mySeat?.status != .done
                ) {
                    game.stakeForMultiplayer(stagedBet)
                    session.placeBet(stagedBet)
                }
            }
        }
    }

    private func canStage(_ value: Int) -> Bool {
        session.mySeat?.status != .done
            && stagedBet + value <= game.player.balance
            && stagedBet + value <= snapshot.maximumBet
    }

    private var actionDock: some View {
        HStack(spacing: 10) {
            MultiplayerAction(title: "Hit", systemImage: "plus.circle.fill",
                              tint: Color(hex: 0x34C759, opacity: 0.26),
                              isEnabled: session.isMyTurn) { session.act(.hit) }

            MultiplayerAction(title: "Stand", systemImage: "hand.raised.fill",
                              tint: Color(hex: 0xFF9500, opacity: 0.26),
                              isEnabled: session.isMyTurn) { session.act(.stand) }

            MultiplayerAction(title: "Double", systemImage: "2.circle.fill",
                              tint: Color(hex: 0x007AFF, opacity: 0.26),
                              isEnabled: canDouble) {
                // The host doubles the stake on its side; the matching chips come
                // out of this device's own balance.
                game.stakeForMultiplayer(session.mySeat?.bet ?? 0)
                session.act(.double)
            }
        }
        .frame(height: 54)
        // §6 — the buttons go quiet when it is not your turn.
        .opacity(session.isMyTurn ? 1 : 0.42)
        .animation(.smooth(duration: 0.25), value: session.isMyTurn)
    }

    private var canDouble: Bool {
        guard session.isMyTurn, let seat = session.mySeat else { return false }
        return seat.cards.count == 2 && game.player.balance >= seat.bet
    }

    @ViewBuilder
    private var summaryDock: some View {
        if session.isHost {
            PrimaryAction(title: "Next round", systemImage: "arrow.counterclockwise",
                          tint: theme.accentTint, height: 54) {
                session.nextRound()
            }
        } else {
            Text("Waiting for the host to deal again…")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textMid)
                .frame(height: 54)
        }
    }
}

/// §6 — name, bet and status only. The hand value stays private until the round
/// resolves, at which point the host sends it.
private struct NamePlate: View {
    @Environment(\.theme) private var theme

    let seat: SeatSnapshot
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(seat.name)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(theme.textDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(seat.bet > 0 ? seat.bet.money : "—")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textMid)

            HStack(spacing: 4) {
                Circle()
                    .fill(tone.dotColor)
                    .frame(width: 6, height: 6)

                // Mid-round this is the status word; once the round resolves the host
                // has sent the hand value and the result, so show those instead.
                Text(resultLine)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(tone.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(plateTint, cornerRadius: 16)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.accentColor, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(seat.name), bet \(seat.bet.money), \(seat.status.label)")
    }

    private var resultLine: String {
        if let outcome = seat.outcome, let total = seat.total {
            return "\(total) · \(outcome.title)"
        }
        if let total = seat.total { return "\(total)" }
        return seat.status.label
    }

    /// Mid-round the colour tracks what the seat is doing; once the result is in it
    /// tracks how the hand went, so a green "Done" never sits next to a loss.
    private var tone: SeatStatus {
        switch seat.outcome {
        case .blackjack: .blackjack
        case .win: .done
        case .bust, .loss: .bust
        case .push: .waiting
        case nil: seat.status
        }
    }

    private var plateTint: Color {
        tone == .bust ? Color(hex: 0xD84A5A, opacity: 0.14) : theme.glassTint
    }
}

private struct MultiplayerAction: View {
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
            }
            .foregroundStyle(theme.textDark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassSurface(tint, cornerRadius: 26, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

// MARK: - Status presentation

extension SeatStatus {
    var label: String {
        switch self {
        case .waiting: "Waiting"
        case .betting: "Betting"
        case .thinking: "Thinking"
        case .done: "Done"
        case .bust: "Bust"
        case .blackjack: "Blackjack"
        case .spectating: "Sitting out"
        }
    }

    var dotColor: Color {
        switch self {
        case .waiting, .spectating: Color(hex: 0x8E9AA6)
        case .betting: Color(hex: 0x007AFF)
        case .thinking: Color(hex: 0xFF9500)
        case .done: Color(hex: 0x34C759)
        case .bust: Color(hex: 0xD84A5A)
        case .blackjack: Color(hex: 0x00A79E)
        }
    }

    var textColor: Color {
        switch self {
        case .waiting, .spectating: Color(hex: 0x5A6570)
        case .betting: Color(hex: 0x0057B8)
        case .thinking: Color(hex: 0xB26A00)
        case .done: Color(hex: 0x1E7A36)
        case .bust: Color(hex: 0xA32C3B)
        case .blackjack: Color(hex: 0x00695F)
        }
    }
}
