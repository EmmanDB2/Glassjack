import SwiftUI
import UIKit

/// The glass a favourite card is cast in.
///
/// The app's own accents offered as translucent tints rather than a free colour
/// picker, so a custom card still reads as Glassjack. The last one is an unlock
/// from the shelf rather than something everybody starts with.
enum CardTint: String, CaseIterable, Identifiable, Codable {
    case clear
    case mint
    case ruby
    case violet
    case amber
    case obsidian

    var id: String { rawValue }

    var name: String {
        switch self {
        case .clear: "Clear"
        case .mint: "Mint"
        case .ruby: "Ruby"
        case .violet: "Violet"
        case .amber: "Amber"
        case .obsidian: "Obsidian"
        }
    }

    /// The swatch in the picker — a little denser than the card, so it reads at 38pt.
    var swatch: Color {
        switch self {
        case .clear: Color(hex: 0x14191F, opacity: 0.10)
        case .mint: Color(hex: 0x00C7BE, opacity: 0.34)
        case .ruby: Color(hex: 0xE04A5A, opacity: 0.30)
        case .violet: Color(hex: 0x8E7DC6, opacity: 0.34)
        case .amber: Color(hex: 0xFFB340, opacity: 0.34)
        case .obsidian: Color(hex: 0x1B1F26, opacity: 0.40)
        }
    }

    /// What the card body is actually filled with.
    var cardTint: Color {
        switch self {
        case .clear: Color(hex: 0x14191F, opacity: 0.055)
        case .mint: Color(hex: 0x00C7BE, opacity: 0.24)
        case .ruby: Color(hex: 0xE04A5A, opacity: 0.20)
        case .violet: Color(hex: 0x8E7DC6, opacity: 0.24)
        case .amber: Color(hex: 0xFFB340, opacity: 0.26)
        case .obsidian: Color(hex: 0x1B1F26, opacity: 0.30)
        }
    }

    /// Non-nil when this tint has to be found in the Game Room first.
    var unlockedBy: String? {
        self == .obsidian ? "chips.obsidian" : nil
    }
}

/// Who you are at the table: a name, a code other people can add you by, and the
/// one card you keep as your face.
@MainActor
final class ProfileStore: ObservableObject {
    @Published var name: String { didSet { defaults.set(name, forKey: Key.name) } }
    @Published var favouriteRank: Rank { didSet { defaults.set(favouriteRank.rawValue, forKey: Key.rank) } }
    @Published var favouriteSuit: Suit { didSet { defaults.set(favouriteSuit.rawValue, forKey: Key.suit) } }
    @Published var favouriteTint: CardTint { didSet { defaults.set(favouriteTint.rawValue, forKey: Key.tint) } }

    /// Six characters, same shape as a multiplayer room code, but yours and stable.
    @Published private(set) var friendCode: String

    private enum Key {
        static let name = "glassjack.profile.name"
        static let rank = "glassjack.profile.favouriteRank"
        static let suit = "glassjack.profile.favouriteSuit"
        static let tint = "glassjack.profile.favouriteTint"
        static let code = "glassjack.profile.friendCode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        name = defaults.string(forKey: Key.name) ?? "You"

        let savedRank = defaults.object(forKey: Key.rank) as? Int
        favouriteRank = savedRank.flatMap(Rank.init(rawValue:)) ?? .ace
        favouriteSuit = defaults.string(forKey: Key.suit).flatMap(Suit.init(rawValue:)) ?? .spades
        favouriteTint = defaults.string(forKey: Key.tint).flatMap(CardTint.init(rawValue:)) ?? .mint

        if let saved = defaults.string(forKey: Key.code), saved.count == 6 {
            friendCode = saved
        } else {
            let generated = Self.makeFriendCode()
            friendCode = generated
            defaults.set(generated, forKey: Key.code)
        }
    }

    var favouriteCard: Card {
        Card(rank: favouriteRank, suit: favouriteSuit)
    }

    /// "Ace of spades, mint glass"
    var favouriteDescription: String {
        "\(favouriteRank.name) of \(favouriteSuit.name.lowercased()), \(favouriteTint.name.lowercased()) glass"
    }

    /// "Ace of spades · Mint"
    var favouriteTitle: String {
        "\(favouriteRank.name) of \(favouriteSuit.name.lowercased()) · \(favouriteTint.name)"
    }

    func copyFriendCode() {
        UIPasteboard.general.string = friendCode
        FeedbackManager.impact(.light)
    }

    /// Letters only, so a code is easy to read out loud.
    private static func makeFriendCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }
}
