import SwiftUI

struct RGBA: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func lerp(_ a: RGBA, _ b: RGBA, _ t: Double) -> RGBA {
        RGBA(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t,
            alpha: a.alpha + (b.alpha - a.alpha) * t
        )
    }
}

/// The lighting the whole app is lit by right now. Rebuilt from device time,
/// never set by hand.
struct AmbientLighting: Equatable {
    var specularHighlight: Color
    var ambientTint: Color
    var warmthFactor: Double
    var label: String
    var iconName: String

    static let neutral = AmbientLighting(
        specularHighlight: .white,
        ambientTint: .clear,
        warmthFactor: 0.35,
        label: "Bright midday light",
        iconName: "sun.max.fill"
    )
}

/// §10.3 — the glass follows the player's clock. Recomputes every five minutes and
/// lerps between the anchors so nothing jumps at an hour boundary.
@MainActor
final class DynamicLightingService: ObservableObject {
    static let shared = DynamicLightingService()

    @Published private(set) var lighting: AmbientLighting = .neutral

    /// When false the app sits at neutral midday light regardless of the clock.
    @Published var followsClock = true {
        didSet { refresh() }
    }

    private var tickTask: Task<Void, Never>?

    private struct Anchor {
        let hour: Double
        let specular: RGBA
        let ambient: RGBA
        let warmth: Double
        let label: String
        let icon: String
    }

    /// Anchored at the centre of each band in the §10.3 time → lighting map.
    private static let anchors: [Anchor] = [
        Anchor(hour: 2.0, specular: RGBA(0xB0A0D0), ambient: RGBA(0x6A5DA8, alpha: 0.10),
               warmth: 0.0, label: "Night light", icon: "moon.stars.fill"),
        Anchor(hour: 8.0, specular: RGBA(0xC8E0F4), ambient: RGBA(0xC8E0F4, alpha: 0.04),
               warmth: 0.15, label: "Cool morning light", icon: "sunrise.fill"),
        Anchor(hour: 13.0, specular: RGBA(0xFFFFFF), ambient: RGBA(0xFFFFFF, alpha: 0.0),
               warmth: 0.35, label: "Bright midday light", icon: "sun.max.fill"),
        Anchor(hour: 17.5, specular: RGBA(0xF4D4B0), ambient: RGBA(0xE8A857, alpha: 0.06),
               warmth: 0.72, label: "Warm afternoon light", icon: "sun.haze.fill"),
        Anchor(hour: 20.5, specular: RGBA(0xE8C090), ambient: RGBA(0xE8A857, alpha: 0.10),
               warmth: 1.0, label: "Evening light", icon: "sunset.fill")
    ]

    private init() {
        refresh()
    }

    func start() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // five minutes
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.refresh() }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    func refresh(now: Date = Date()) {
        let next = followsClock ? Self.computeLighting(at: now) : .neutral
        guard next != lighting else { return }
        withAnimation(.smooth(duration: 0.9)) {
            lighting = next
        }
    }

    /// True once the player has been up past the Midnight floor's opening hour.
    static func isAfter(hour: Int, now: Date = Date()) -> Bool {
        Calendar.current.component(.hour, from: now) >= hour
    }

    static func computeLighting(at date: Date) -> AmbientLighting {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 12) + Double(components.minute ?? 0) / 60

        let (lower, upper, t) = bracket(for: hour)
        return AmbientLighting(
            specularHighlight: RGBA.lerp(lower.specular, upper.specular, t).color,
            ambientTint: RGBA.lerp(lower.ambient, upper.ambient, t).color,
            warmthFactor: lower.warmth + (upper.warmth - lower.warmth) * t,
            // The label snaps to whichever anchor is nearer, so the caption reads as a mood.
            label: t < 0.5 ? lower.label : upper.label,
            iconName: t < 0.5 ? lower.icon : upper.icon
        )
    }

    /// Finds the two anchors the given hour sits between, wrapping around midnight.
    private static func bracket(for hour: Double) -> (Anchor, Anchor, Double) {
        let anchors = Self.anchors

        for index in 0..<(anchors.count - 1) where hour >= anchors[index].hour && hour < anchors[index + 1].hour {
            let lower = anchors[index]
            let upper = anchors[index + 1]
            return (lower, upper, (hour - lower.hour) / (upper.hour - lower.hour))
        }

        // Between the last evening anchor and the night anchor on the far side of midnight.
        guard let evening = anchors.last, let night = anchors.first else {
            return (anchors[0], anchors[0], 0)
        }
        let span = (24 - evening.hour) + night.hour
        let travelled = hour >= evening.hour ? hour - evening.hour : (24 - evening.hour) + hour
        return (evening, night, span > 0 ? travelled / span : 0)
    }
}
