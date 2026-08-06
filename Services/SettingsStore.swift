import SwiftUI

/// Everything the Settings screen owns. Persisted locally — the game never needs an account.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var hapticsEnabled: Bool { didSet { persist(hapticsEnabled, .haptics) } }
    @Published var ambientMusicEnabled: Bool { didSet { persist(ambientMusicEnabled, .music) } }
    @Published var followsClock: Bool { didSet { persist(followsClock, .followsClock) } }
    @Published var fullGlassBlur: Bool { didSet { persist(fullGlassBlur, .glassBlur) } }
    @Published private(set) var hasSupporterPack: Bool

    private enum Key: String {
        case haptics = "glassjack.settings.haptics"
        case music = "glassjack.settings.music"
        case followsClock = "glassjack.settings.followsClock"
        case glassBlur = "glassjack.settings.glassBlur"
        case supporter = "glassjack.settings.supporterPack"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Key.haptics.rawValue) as? Bool ?? true
        ambientMusicEnabled = defaults.object(forKey: Key.music.rawValue) as? Bool ?? true
        followsClock = defaults.object(forKey: Key.followsClock.rawValue) as? Bool ?? true
        // §11.1: full blur is opt-out, and the device tier check can turn it off on first launch.
        fullGlassBlur = defaults.object(forKey: Key.glassBlur.rawValue) as? Bool ?? DevicePerformance.supportsFullBlur
        hasSupporterPack = defaults.bool(forKey: Key.supporter.rawValue)
    }

    /// Marks the one-time Supporter Pack as owned. Cosmetics only — nothing here touches play.
    func grantSupporterPack() {
        hasSupporterPack = true
        defaults.set(true, forKey: Key.supporter.rawValue)
    }

    private func persist(_ value: Bool, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}

/// §11.1 — decide once whether this device should be running every glass surface.
enum DevicePerformance {
    static var supportsFullBlur: Bool {
        // ProcessInfo is the closest stand-in for device_info_plus without adding a dependency.
        ProcessInfo.processInfo.processorCount >= 6 && ProcessInfo.processInfo.physicalMemory >= 4_000_000_000
    }
}

// MARK: - Blur-aware glass surfaces

private struct GlassBlurEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Read by every glass surface before it reaches for a real blur (§11.1).
    var glassBlurEnabled: Bool {
        get { self[GlassBlurEnabledKey.self] }
        set { self[GlassBlurEnabledKey.self] = newValue }
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    @Environment(\.glassBlurEnabled) private var blurEnabled

    let tint: Color
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        if blurEnabled {
            content.glassEffect(interactive ? .regular.tint(tint).interactive() : .regular.tint(tint), in: shape)
        } else {
            content
                .background(shape.fill(Color.white.opacity(0.55)))
                .background(shape.fill(tint))
                .overlay(shape.stroke(Color.white.opacity(0.75), lineWidth: 1))
        }
    }
}

extension View {
    /// A frosted panel that quietly degrades to a flat translucent surface when
    /// `fullGlassBlur` is off. Use this instead of calling `glassEffect` directly.
    func glassSurface<S: Shape>(_ tint: Color, in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(tint: tint, shape: shape, interactive: interactive))
    }

    func glassSurface(_ tint: Color, cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        glassSurface(tint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), interactive: interactive)
    }

    func glassCapsule(_ tint: Color, interactive: Bool = false) -> some View {
        glassSurface(tint, in: Capsule(), interactive: interactive)
    }
}
