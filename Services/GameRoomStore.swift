import SwiftUI

enum RoomCategory: String, CaseIterable, Identifiable, Codable {
    case cardBacks
    case chipSets
    case felts
    case decor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cardBacks: "Card backs"
        case .chipSets: "Chip sets"
        case .felts: "Felts"
        case .decor: "Decor"
        }
    }
}

/// What a player has to do for something to quietly appear on the shelf.
/// The caption is written over the silhouette — §7 says no counters and no bars.
enum UnlockTrigger: Hashable, Codable {
    case always
    case handsPlayed(Int)
    case winsInSession(Int)
    case blackjackHit
    case multiplayerRound
    case afterHour(Int)
    case dailyStreak(Int)

    var caption: String {
        switch self {
        case .always: "Yours from the start"
        case .handsPlayed(let count): "Play \(count) hands"
        case .winsInSession(let count): "Win \(count) in a session"
        case .blackjackHit: "Hit blackjack"
        case .multiplayerRound: "Play\ntogether"
        case .afterHour(let hour): "Play after \(hour > 12 ? "\(hour - 12)pm" : "\(hour)am")"
        case .dailyStreak(let days): "\(days) day\nstreak"
        }
    }
}

struct RoomItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: RoomCategory
    let trigger: UnlockTrigger
    let swatch: Color
    /// Card backs only: the pattern printed on them. Everything else leaves it nil.
    var cardBackDesign: CardBackDesign?
    /// Chip sets show three beads; everything else uses `swatch`.
    var palette: [Color] = []
    /// Decor items are drawn as a symbol rather than a colour chip.
    var symbol: String?
}

/// Counters the unlock conditions read. Kept deliberately out of sight — the player
/// never sees a number, only a thing that has appeared.
struct ProgressStats: Codable, Equatable {
    var handsPlayed = 0
    var wins = 0
    var blackjacks = 0
    var multiplayerRounds = 0
    var dailyStreak = 1
    var latestHourPlayed = 0
    var lastPlayedDay: Date?
    /// The best single round, and where it happened. The Profile's one brag line.
    var biggestPot = 0
    var biggestPotFloor = ""
    /// How often each card has come to you, keyed "rank-suit". Feeds the line under
    /// the favourite card. At most 52 entries.
    var cardsSeen: [String: Int] = [:]

    var winRate: Double {
        guard handsPlayed > 0 else { return 0 }
        return Double(wins) / Double(handsPlayed)
    }

    init() {}

    /// Decoded by hand rather than by the compiler. A synthesised decoder throws on
    /// a key it has not seen before, so adding one counter here would quietly wipe
    /// the progress of everybody who already has a saved blob. Every field falls
    /// back to its default instead.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        handsPlayed = try values.decodeIfPresent(Int.self, forKey: .handsPlayed) ?? 0
        wins = try values.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        blackjacks = try values.decodeIfPresent(Int.self, forKey: .blackjacks) ?? 0
        multiplayerRounds = try values.decodeIfPresent(Int.self, forKey: .multiplayerRounds) ?? 0
        dailyStreak = try values.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 1
        latestHourPlayed = try values.decodeIfPresent(Int.self, forKey: .latestHourPlayed) ?? 0
        lastPlayedDay = try values.decodeIfPresent(Date.self, forKey: .lastPlayedDay)
        biggestPot = try values.decodeIfPresent(Int.self, forKey: .biggestPot) ?? 0
        biggestPotFloor = try values.decodeIfPresent(String.self, forKey: .biggestPotFloor) ?? ""
        cardsSeen = try values.decodeIfPresent([String: Int].self, forKey: .cardsSeen) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case handsPlayed, wins, blackjacks, multiplayerRounds, dailyStreak
        case latestHourPlayed, lastPlayedDay, biggestPot, biggestPotFloor, cardsSeen
    }
}

/// §7 — the Game Room. Playing fills it out; nothing announces itself with a popup.
@MainActor
final class GameRoomStore: ObservableObject {
    @Published private(set) var unlockedIDs: Set<String>
    @Published private(set) var stats: ProgressStats
    /// Drives the soft glow on the hub's Game Room row.
    @Published private(set) var hasUndiscoveredItems: Bool
    /// The specific things that glow on the shelf until the player has looked.
    @Published private(set) var newlyUnlockedIDs: Set<String>
    @Published private(set) var winsThisSession = 0

    @Published var selectedCardBackID: String { didSet { defaults.set(selectedCardBackID, forKey: Key.cardBack) } }
    @Published var selectedChipSetID: String { didSet { defaults.set(selectedChipSetID, forKey: Key.chipSet) } }
    @Published var selectedFeltID: String { didSet { defaults.set(selectedFeltID, forKey: Key.felt) } }

    private enum Key {
        static let unlocked = "glassjack.room.unlocked"
        static let stats = "glassjack.room.stats"
        static let unseen = "glassjack.room.unseen"
        static let newIDs = "glassjack.room.newIDs"
        static let cardBack = "glassjack.room.cardBack"
        static let chipSet = "glassjack.room.chipSet"
        static let felt = "glassjack.room.felt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.stringArray(forKey: Key.unlocked) ?? []
        var unlocked = Set(saved)
        for item in RoomItem.catalog where item.trigger == .always {
            unlocked.insert(item.id)
        }
        unlockedIDs = unlocked

        if let data = defaults.data(forKey: Key.stats),
           let decoded = try? JSONDecoder().decode(ProgressStats.self, from: data) {
            stats = decoded
        } else {
            stats = ProgressStats()
        }

        hasUndiscoveredItems = defaults.bool(forKey: Key.unseen)
        newlyUnlockedIDs = Set(defaults.stringArray(forKey: Key.newIDs) ?? [])
        selectedCardBackID = defaults.string(forKey: Key.cardBack) ?? RoomItem.defaultCardBack.id
        selectedChipSetID = defaults.string(forKey: Key.chipSet) ?? RoomItem.defaultChipSet.id
        selectedFeltID = defaults.string(forKey: Key.felt) ?? RoomItem.defaultFelt.id

        rollDailyStreak()
    }

    // MARK: - Reading the shelf

    func items(in category: RoomCategory) -> [RoomItem] {
        RoomItem.catalog.filter { $0.category == category }
    }

    func isUnlocked(_ item: RoomItem) -> Bool {
        unlockedIDs.contains(item.id)
    }

    func unlockedCount(in category: RoomCategory) -> Int {
        items(in: category).filter(isUnlocked).count
    }

    func countLabel(for category: RoomCategory) -> String {
        let all = items(in: category)
        return "\(all.filter(isUnlocked).count) of \(all.count)"
    }

    var selectedFeltColor: Color {
        RoomItem.catalog.first { $0.id == selectedFeltID }?.swatch ?? RoomItem.defaultFelt.swatch
    }

    var selectedCardBackTint: Color {
        RoomItem.catalog.first { $0.id == selectedCardBackID }?.swatch ?? RoomItem.defaultCardBack.swatch
    }

    var selectedCardBackDesign: CardBackDesign {
        RoomItem.catalog.first { $0.id == selectedCardBackID }?.cardBackDesign ?? .lattice
    }

    /// Non-empty only when the player has picked a set other than the house one,
    /// so the default per-denomination colours survive until they choose otherwise.
    var selectedChipPalette: [Color] {
        guard selectedChipSetID != RoomItem.defaultChipSet.id,
              let set = RoomItem.catalog.first(where: { $0.id == selectedChipSetID }) else { return [] }
        return set.palette
    }

    func isNew(_ item: RoomItem) -> Bool {
        newlyUnlockedIDs.contains(item.id)
    }

    /// Picks an item, if it has been found. Locked items ignore the tap.
    func select(_ item: RoomItem) {
        guard isUnlocked(item) else { return }
        switch item.category {
        case .cardBacks: selectedCardBackID = item.id
        case .chipSets: selectedChipSetID = item.id
        case .felts: selectedFeltID = item.id
        case .decor: break
        }
        FeedbackManager.impact(.light)
    }

    func isSelected(_ item: RoomItem) -> Bool {
        switch item.category {
        case .cardBacks: item.id == selectedCardBackID
        case .chipSets: item.id == selectedChipSetID
        case .felts: item.id == selectedFeltID
        case .decor: false
        }
    }

    /// Called when the player opens the Game Room — the glow has done its job.
    func markShelfSeen() {
        guard hasUndiscoveredItems || !newlyUnlockedIDs.isEmpty else { return }
        hasUndiscoveredItems = false
        newlyUnlockedIDs = []
        defaults.set(false, forKey: Key.unseen)
        defaults.set([String](), forKey: Key.newIDs)
    }

    // MARK: - Recording play

    func beginSession() {
        winsThisSession = 0
    }

    /// Records one resolved hand and returns anything that quietly appeared because of it.
    @discardableResult
    func recordHand(
        outcome: RoundOutcome,
        isFractured: Bool,
        net: Int = 0,
        floor: String = "",
        now: Date = Date()
    ) -> [RoomItem] {
        // §8: Fractured never feeds Game Room progression.
        guard !isFractured else { return [] }

        stats.handsPlayed += 1
        if outcome == .blackjack { stats.blackjacks += 1 }
        if outcome == .win || outcome == .blackjack {
            winsThisSession += 1
            stats.wins += 1
        }
        if net > stats.biggestPot {
            stats.biggestPot = net
            stats.biggestPotFloor = floor
        }
        stats.latestHourPlayed = max(stats.latestHourPlayed, Calendar.current.component(.hour, from: now))
        persistStats()
        return reevaluateUnlocks()
    }

    /// One card dealt to the player. Fractured is skipped, like every other counter.
    func recordDealtCard(_ card: Card, isFractured: Bool) {
        guard !isFractured else { return }
        stats.cardsSeen[Self.cardKey(card), default: 0] += 1
        persistStats()
    }

    func timesSeen(_ card: Card) -> Int {
        stats.cardsSeen[Self.cardKey(card)] ?? 0
    }

    private static func cardKey(_ card: Card) -> String {
        "\(card.rank.rawValue)-\(card.suit.rawValue)"
    }

    @discardableResult
    func recordMultiplayerRound() -> [RoomItem] {
        stats.multiplayerRounds += 1
        persistStats()
        return reevaluateUnlocks()
    }

    /// Re-checks every locked item against the current counters.
    @discardableResult
    private func reevaluateUnlocks() -> [RoomItem] {
        let discovered = RoomItem.catalog.filter { !unlockedIDs.contains($0.id) && satisfies($0.trigger) }
        guard !discovered.isEmpty else { return [] }

        for item in discovered {
            unlockedIDs.insert(item.id)
            newlyUnlockedIDs.insert(item.id)
        }
        defaults.set(Array(unlockedIDs), forKey: Key.unlocked)
        defaults.set(Array(newlyUnlockedIDs), forKey: Key.newIDs)
        hasUndiscoveredItems = true
        defaults.set(true, forKey: Key.unseen)
        return discovered
    }

    private func satisfies(_ trigger: UnlockTrigger) -> Bool {
        switch trigger {
        case .always: true
        case .handsPlayed(let count): stats.handsPlayed >= count
        case .winsInSession(let count): winsThisSession >= count
        case .blackjackHit: stats.blackjacks >= 1
        case .multiplayerRound: stats.multiplayerRounds >= 1
        case .afterHour(let hour): stats.latestHourPlayed >= hour
        case .dailyStreak(let days): stats.dailyStreak >= days
        }
    }

    /// A launch a day keeps the streak; a gap resets it to one.
    private func rollDailyStreak(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        guard let last = stats.lastPlayedDay else {
            stats.lastPlayedDay = today
            stats.dailyStreak = 1
            persistStats()
            return
        }

        let lastDay = calendar.startOfDay(for: last)
        guard lastDay != today else { return }

        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        stats.dailyStreak = gap == 1 ? stats.dailyStreak + 1 : 1
        stats.lastPlayedDay = today
        persistStats()
        reevaluateUnlocks()
    }

    private func persistStats() {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: Key.stats)
    }
}

// MARK: - Catalog

extension RoomItem {
    static let defaultCardBack = RoomItem(
        id: "back.frosted", name: "Frosted Geometric", category: .cardBacks,
        trigger: .always, swatch: Color(hex: 0x5AD7E1, opacity: 0.28),
        cardBackDesign: .lattice
    )

    static let defaultChipSet = RoomItem(
        id: "chips.house", name: "House Glass", category: .chipSets, trigger: .always,
        swatch: Color(hex: 0x00C7BE, opacity: 0.42),
        palette: [
            Color(hex: 0x00C7BE, opacity: 0.42),
            Color(hex: 0xD84A5A, opacity: 0.42),
            Color(hex: 0x8E7DC6, opacity: 0.42)
        ]
    )

    static let defaultFelt = RoomItem(
        id: "felt.linen", name: "Warm Linen", category: .felts,
        trigger: .always, swatch: .white
    )

    static let catalog: [RoomItem] = [
        // Card backs — three designs across six colourways.
        defaultCardBack,
        RoomItem(id: "back.wordmark", name: "House Mark", category: .cardBacks,
                 trigger: .always, swatch: Color(hex: 0x00C7BE, opacity: 0.30),
                 cardBackDesign: .wordmark),
        RoomItem(id: "back.midnight", name: "Midnight Grid", category: .cardBacks,
                 trigger: .handsPlayed(10), swatch: Color(hex: 0x8E7DC6, opacity: 0.30),
                 cardBackDesign: .lattice),
        RoomItem(id: "back.ocean", name: "Deep Ocean", category: .cardBacks,
                 trigger: .winsInSession(3), swatch: Color(hex: 0x2A6FA8, opacity: 0.30),
                 cardBackDesign: .rain),
        RoomItem(id: "back.botanical", name: "Pressed Gold", category: .cardBacks,
                 trigger: .blackjackHit, swatch: Color(hex: 0xC9A227, opacity: 0.30),
                 cardBackDesign: .wordmark),
        RoomItem(id: "back.rain", name: "Late Night Rain", category: .cardBacks,
                 trigger: .afterHour(22), swatch: Color(hex: 0x4A5A78, opacity: 0.32),
                 cardBackDesign: .rain),

        // Chip sets — 4
        defaultChipSet,
        RoomItem(id: "chips.quartz", name: "Rose Quartz", category: .chipSets,
                 trigger: .dailyStreak(7), swatch: Color(hex: 0xE2A0B0, opacity: 0.44),
                 palette: [
                     Color(hex: 0xE2A0B0, opacity: 0.44),
                     Color(hex: 0xF0C8D2, opacity: 0.44),
                     Color(hex: 0xC98094, opacity: 0.44)
                 ]),
        RoomItem(id: "chips.obsidian", name: "Obsidian", category: .chipSets,
                 trigger: .handsPlayed(50), swatch: Color(hex: 0x1B1F26, opacity: 0.55),
                 palette: [
                     Color(hex: 0x1B1F26, opacity: 0.55),
                     Color(hex: 0x39424F, opacity: 0.55),
                     Color(hex: 0x5A6675, opacity: 0.55)
                 ]),
        RoomItem(id: "chips.amber", name: "Smoked Amber", category: .chipSets,
                 trigger: .multiplayerRound, swatch: Color(hex: 0xCFA03A, opacity: 0.46),
                 palette: [
                     Color(hex: 0xCFA03A, opacity: 0.46),
                     Color(hex: 0xE8C46E, opacity: 0.46),
                     Color(hex: 0x9C7420, opacity: 0.46)
                 ]),

        // Felts — 4
        defaultFelt,
        RoomItem(id: "felt.sage", name: "Soft Sage", category: .felts,
                 trigger: .always, swatch: Color(hex: 0xB9C9B4)),
        RoomItem(id: "felt.navy", name: "Dusty Navy", category: .felts,
                 trigger: .always, swatch: Color(hex: 0x8FA0B8)),
        RoomItem(id: "felt.slate", name: "Slate", category: .felts,
                 trigger: .winsInSession(3), swatch: Color(hex: 0x5E6B78)),

        // Decor — 6
        RoomItem(id: "decor.plant", name: "Trailing Plant", category: .decor,
                 trigger: .always, swatch: Color(hex: 0x00C7BE, opacity: 0.30), symbol: "leaf.fill"),
        RoomItem(id: "decor.lamp", name: "Corner Lamp", category: .decor,
                 trigger: .blackjackHit, swatch: Color(hex: 0xE8C090, opacity: 0.30), symbol: "lamp.table.fill"),
        RoomItem(id: "decor.mug", name: "Second Mug", category: .decor,
                 trigger: .handsPlayed(25), swatch: Color(hex: 0xB2764A, opacity: 0.30), symbol: "cup.and.saucer.fill"),
        RoomItem(id: "decor.chair", name: "Second Chair", category: .decor,
                 trigger: .multiplayerRound, swatch: Color(hex: 0x8E7DC6, opacity: 0.30), symbol: "chair.lounge.fill"),
        RoomItem(id: "decor.shelf", name: "Bookshelf", category: .decor,
                 trigger: .handsPlayed(75), swatch: Color(hex: 0x6FA86B, opacity: 0.30), symbol: "books.vertical.fill"),
        RoomItem(id: "decor.window", name: "Rooftop Window", category: .decor,
                 trigger: .dailyStreak(7), swatch: Color(hex: 0x4A5A78, opacity: 0.30), symbol: "moon.stars.fill")
    ]
}
