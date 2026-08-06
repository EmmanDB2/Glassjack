import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// A chip the player can tap during betting. Colour and label come from the theme,
/// never from the betting UI.
struct ChipDenomination: Identifiable, Hashable {
    let value: Int
    let label: String
    let color: Color

    var id: Int { value }

    init(value: Int, label: String? = nil, color: Color) {
        self.value = value
        self.label = label ?? ChipDenomination.shortLabel(for: value)
        self.color = color
    }

    static func shortLabel(for value: Int) -> String {
        if value >= 1_000 {
            let thousands = Double(value) / 1_000
            let trimmed = thousands.rounded() == thousands
                ? String(Int(thousands))
                : String(format: "%.1f", thousands)
            return "$\(trimmed)K"
        }
        return "$\(value)"
    }
}

enum CardStyle {
    case liquidGlass
    case classic
}

/// What is printed on the back of a card. Backs found in the Game Room change this
/// as well as the tint, so a new back is a new object rather than a recolour.
enum CardBackDesign: String, Codable, Hashable, CaseIterable {
    /// The house back: a lattice of diamonds around a single larger one.
    case lattice
    /// The wordmark, sparkles and all, exactly as it reads on the table.
    case wordmark
    /// Slanted streaks running off the top corner.
    case rain
}

/// Every visual parameter in one place. A new casino floor is a new `ThemeConfig`
/// and nothing else.
struct ThemeConfig {
    // Environment
    var shellBackground: Color = .white
    var backgroundBlob: Color = Color(hex: 0x00C7BE)
    var backgroundBlobOpacity: Double = 0.17
    /// §4 / design 1A — the room's light, as two soft blooms either side of the
    /// table. Cool where the dealer stands, warm at the edge nearest the player.
    var auroraCool: Color = Color(hex: 0x7AD6FF)
    var auroraWarm: Color = Color(hex: 0xFFC48C)
    var auroraOpacity: Double = 0.34
    var backgroundShade: Double = 0.05
    var tableFeltColor: Color = .white
    var usesDarkChrome = false

    // Cards
    var cardStyle: CardStyle = .liquidGlass
    var cardBackTint: Color = Color(hex: 0x5AD7E1, opacity: 0.20)
    var cardBackDesign: CardBackDesign = .lattice
    var redSuitColor: Color = Color(hex: 0xC2101F)
    var blackSuitColor: Color = Color(hex: 0x14191F)

    // Chips
    var chipDenominations: [ChipDenomination] = ChipDenomination.casinoFloorSet

    // UI colours
    var primaryColor: Color = Color(hex: 0x00A79E)
    var accentColor: Color = Color(hex: 0x00C7BE)
    var textDark: Color = Color(hex: 0x14191F)
    var textMid: Color = Color(hex: 0x3C3C43, opacity: 0.60)
    var textLight: Color = Color(hex: 0x3C3C43, opacity: 0.45)

    // Glass tokens — the four surfaces every screen is built from
    var pillTint: Color = Color(hex: 0x00C7BE, opacity: 0.24)
    var glassTint: Color = Color.white.opacity(0.60)
    var accentTint: Color = Color(hex: 0x00C7BE, opacity: 0.30)
    var hairline: Color = Color.white.opacity(0.92)
    var dashColor: Color = Color(hex: 0x3C3C43, opacity: 0.32)
    var ghostColor: Color = Color(hex: 0x3C3C43, opacity: 0.16)
    var silhouette: Color = Color(hex: 0x3C3C43, opacity: 0.10)

    // Dynamic lighting — recomputed from device time by DynamicLightingService (§10.3)
    var specularHighlightColor: Color = .white
    var ambientTintColor: Color = .clear
    var warmthFactor: Double = 0.5

    // Performance — checked before every glass surface (§11.1)
    var useBackdropBlur = true

    var wordmarkFont: Font = .system(size: 32, weight: .black, design: .rounded)
    var musicTracks: [MusicTrack] = [.track1, .track2]

    /// Applies the current time-of-day lighting on top of a preset's base theme.
    func applying(_ lighting: AmbientLighting) -> ThemeConfig {
        var copy = self
        copy.specularHighlightColor = lighting.specularHighlight
        copy.ambientTintColor = lighting.ambientTint
        copy.warmthFactor = lighting.warmthFactor
        return copy
    }

    func withBlur(_ enabled: Bool) -> ThemeConfig {
        var copy = self
        copy.useBackdropBlur = enabled
        return copy
    }
}

extension ChipDenomination {
    /// House denominations, in the colours a real floor uses: red, blue, green,
    /// orange, charcoal. Shared by the Casino Floor and Midnight.
    static let casinoFloorSet: [ChipDenomination] = [
        ChipDenomination(value: 5, color: Color(hex: 0xD84A5A, opacity: 0.46)),
        ChipDenomination(value: 10, color: Color(hex: 0x007AFF, opacity: 0.44)),
        ChipDenomination(value: 25, color: Color(hex: 0x34C759, opacity: 0.44)),
        ChipDenomination(value: 50, color: Color(hex: 0xFF9500, opacity: 0.46)),
        ChipDenomination(value: 100, color: Color(hex: 0x2E3440, opacity: 0.52))
    ]

    static let highRollerSet: [ChipDenomination] = [
        ChipDenomination(value: 500, color: Color(hex: 0xD9AD4D, opacity: 0.50)),
        ChipDenomination(value: 1_000, color: Color(hex: 0xE0B85C, opacity: 0.50)),
        ChipDenomination(value: 2_500, color: Color(hex: 0xE8C46E, opacity: 0.52)),
        ChipDenomination(value: 5_000, color: Color(hex: 0xF0DCA8, opacity: 0.54)),
        ChipDenomination(value: 10_000, color: Color(hex: 0xFAEBC4, opacity: 0.56))
    ]

    static let quietSet: [ChipDenomination] = [
        ChipDenomination(value: 5, color: Color(hex: 0x8FA0B8, opacity: 0.44)),
        ChipDenomination(value: 10, color: Color(hex: 0x00C7BE, opacity: 0.44)),
        ChipDenomination(value: 25, color: Color(hex: 0xB9C9B4, opacity: 0.48)),
        ChipDenomination(value: 100, color: Color(hex: 0xC9A227, opacity: 0.44))
    ]

    static let fracturedSet: [ChipDenomination] = [
        ChipDenomination(value: 10, color: Color(hex: 0x8E7DC6, opacity: 0.46)),
        ChipDenomination(value: 25, color: Color(hex: 0x9C8AD8, opacity: 0.44)),
        ChipDenomination(value: 100, color: Color(hex: 0x6E5DAE, opacity: 0.48)),
        ChipDenomination(value: 500, color: Color(hex: 0xCFC4F5, opacity: 0.50))
    ]
}

extension ThemeConfig {
    static let casinoFloor = ThemeConfig()

    static let highRoller = ThemeConfig(
        shellBackground: Color(hex: 0x0E0B08),
        backgroundBlob: Color(hex: 0xD9AD4D),
        backgroundBlobOpacity: 0.26,
        backgroundShade: 0.26,
        tableFeltColor: Color(hex: 0x1B1611),
        usesDarkChrome: true,
        cardBackTint: Color(hex: 0xD9AD4D, opacity: 0.18),
        chipDenominations: ChipDenomination.highRollerSet,
        primaryColor: Color(hex: 0xD9AD4D),
        accentColor: Color(hex: 0xF0DCA8),
        textDark: Color(hex: 0xF0DCA8),
        textMid: Color(hex: 0xF0DCA8, opacity: 0.60),
        textLight: Color(hex: 0xF0DCA8, opacity: 0.42),
        pillTint: Color(hex: 0xD9AD4D, opacity: 0.20),
        glassTint: Color.white.opacity(0.10),
        accentTint: Color(hex: 0xD9AD4D, opacity: 0.26),
        hairline: Color(hex: 0xD9AD4D, opacity: 0.45),
        dashColor: Color(hex: 0xF0DCA8, opacity: 0.28),
        ghostColor: Color(hex: 0xF0DCA8, opacity: 0.16),
        silhouette: Color(hex: 0xF0DCA8, opacity: 0.10),
        wordmarkFont: .system(size: 32, weight: .semibold, design: .serif),
        musicTracks: [.track3, .track4]
    )

    static let midnight = ThemeConfig(
        shellBackground: Color(hex: 0x121722),
        backgroundBlob: Color(hex: 0x5A7AD7),
        backgroundBlobOpacity: 0.24,
        backgroundShade: 0.22,
        tableFeltColor: Color(hex: 0x1A2130),
        usesDarkChrome: true,
        cardBackTint: Color(hex: 0x5A7AD7, opacity: 0.20),
        chipDenominations: ChipDenomination.casinoFloorSet,
        primaryColor: Color(hex: 0x8FB4FF),
        accentColor: Color(hex: 0xA8C6FF),
        textDark: Color(hex: 0xE8EEFB),
        textMid: Color(hex: 0xE8EEFB, opacity: 0.60),
        textLight: Color(hex: 0xE8EEFB, opacity: 0.42),
        pillTint: Color(hex: 0x8FB4FF, opacity: 0.20),
        glassTint: Color.white.opacity(0.12),
        accentTint: Color(hex: 0x8FB4FF, opacity: 0.26),
        hairline: Color.white.opacity(0.24),
        dashColor: Color(hex: 0xE8EEFB, opacity: 0.28),
        ghostColor: Color(hex: 0xE8EEFB, opacity: 0.16),
        silhouette: Color(hex: 0xE8EEFB, opacity: 0.10),
        musicTracks: [.track2, .track3]
    )

    static let morningCafe = ThemeConfig(
        shellBackground: Color(hex: 0xFFF8F0),
        backgroundBlob: Color(hex: 0xE8B98A),
        backgroundBlobOpacity: 0.22,
        backgroundShade: 0.04,
        tableFeltColor: Color(hex: 0xFFF8F0),
        cardBackTint: Color(hex: 0xE8B98A, opacity: 0.22),
        chipDenominations: ChipDenomination.quietSet,
        primaryColor: Color(hex: 0xB2764A),
        accentColor: Color(hex: 0xE8B98A),
        pillTint: Color(hex: 0xE8B98A, opacity: 0.28),
        accentTint: Color(hex: 0xE8B98A, opacity: 0.34),
        musicTracks: [.track1, .track4]
    )

    static let fractured = ThemeConfig(
        shellBackground: .white,
        backgroundBlob: Color(hex: 0x8E7DC6),
        backgroundBlobOpacity: 0.20,
        backgroundShade: 0.06,
        cardBackTint: Color(hex: 0x8E7DC6, opacity: 0.24),
        chipDenominations: ChipDenomination.fracturedSet,
        primaryColor: Color(hex: 0x6E5DAE),
        accentColor: Color(hex: 0x8E7DC6),
        pillTint: Color(hex: 0x8E7DC6, opacity: 0.22),
        accentTint: Color(hex: 0x8E7DC6, opacity: 0.30),
        musicTracks: [.track2, .track4]
    )
}
