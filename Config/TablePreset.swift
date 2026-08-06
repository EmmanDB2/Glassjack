import SwiftUI

/// What the player has to do before a floor opens up. Copy lives here so the
/// Tables screen never writes its own unlock strings.
enum UnlockRequirement: Equatable {
    case always
    case balance(Int)
    case playAfterHour(Int)
    case dailyStreak(Int)

    var caption: String {
        switch self {
        case .always:
            ""
        case .balance(let amount):
            "Reach $\(amount.formattedMoney) to be let in."
        case .playAfterHour(let hour):
            "Play a hand after \(hour > 12 ? "\(hour - 12)pm" : "\(hour)am") to find this one open."
        case .dailyStreak(let days):
            "\(days) days in a row opens the café."
        }
    }
}

/// A named combination of rules and looks. Creating a new floor or mode is a new preset
/// and nothing else.
struct TablePreset: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let tagline: String
    let rules: GameConfig
    let theme: ThemeConfig
    let unlock: UnlockRequirement

    /// Fractured tables run off a session stack and never feed Game Room progress.
    var isFractured: Bool { rules.usesSessionStack }

    var limitsLabel: String {
        "$\(rules.minimumBet.formattedMoney)–$\(rules.maximumBet.formattedMoney)"
    }

    var shoeLabel: String {
        "\(rules.numberOfDecks) decks"
    }

    var blackjackLabel: String {
        let ratio = rules.blackjackPayout
        if abs(ratio - 1.5) < 0.001 { return "3 : 2" }
        if abs(ratio - 1.2) < 0.001 { return "6 : 5" }
        return String(format: "%.2f : 1", ratio)
    }

    var rulesLine: String {
        var parts = [rules.dealerHitsSoft17 ? "Dealer hits soft 17" : "Dealer stands on soft 17"]
        var options: [String] = []
        if rules.allowSplit { options.append("split") }
        if rules.allowDouble { options.append("double") }
        if rules.allowInsurance { options.append("insurance") }
        if !options.isEmpty { parts.append(options.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

extension TablePreset {
    static let casinoFloor = TablePreset(
        id: "classic",
        name: "Casino Floor",
        iconName: "table.furniture.fill",
        tagline: "The house table. Nothing bent, nothing hidden.",
        rules: .casinoFloor,
        theme: .casinoFloor,
        unlock: .always
    )

    static let highRoller = TablePreset(
        id: "highroller",
        name: "High Roller Room",
        iconName: "crown.fill",
        tagline: "Drop below the $500 minimum and you are escorted out.",
        rules: .highRoller,
        theme: .highRoller,
        unlock: .balance(5_000)
    )

    static let midnight = TablePreset(
        id: "midnight",
        name: "Midnight",
        iconName: "moon.stars.fill",
        tagline: "Dealer stands on soft 17, and the lamps are already down.",
        rules: .midnight,
        theme: .midnight,
        unlock: .playAfterHour(22)
    )

    static let morningCafe = TablePreset(
        id: "morningcafe",
        name: "Morning Café",
        iconName: "cup.and.saucer.fill",
        tagline: "Two decks, small limits, no hurry at all.",
        rules: .morningCafe,
        theme: .morningCafe,
        unlock: .dailyStreak(7)
    )

    static let fractured = TablePreset(
        id: "fractured",
        name: "Fractured",
        iconName: "circle.hexagongrid.fill",
        tagline: "Bent rules. Separate stack. No stakes.",
        rules: .fractured,
        theme: .fractured,
        unlock: .always
    )

    /// Everything the Tables screen lists, in the order it lists them.
    static let floors: [TablePreset] = [casinoFloor, highRoller, midnight, morningCafe]

    static func preset(id: String) -> TablePreset {
        (floors + [fractured]).first { $0.id == id } ?? casinoFloor
    }
}

extension Int {
    /// 2500 → "2,500". Used everywhere money is shown.
    var formattedMoney: String {
        let digits = Array(String(abs(self)))
        var grouped = ""
        for (offset, digit) in digits.enumerated() {
            if offset > 0 && (digits.count - offset).isMultiple(of: 3) {
                grouped.append(",")
            }
            grouped.append(digit)
        }
        return self < 0 ? "-\(grouped)" : grouped
    }

    /// 2500 → "$2,500".
    var money: String { "$\(formattedMoney)" }

    /// 2500 → "+$2,500", -180 → "−$180". Used by the round summary.
    var signedMoney: String {
        self < 0 ? "−$\(abs(self).formattedMoney)" : "+$\(formattedMoney)"
    }
}
