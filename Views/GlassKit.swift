import SwiftUI

// MARK: - Theme plumbing

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeConfig()
}

extension EnvironmentValues {
    /// The active table's look. Every screen reads colours from here, never from a literal.
    var theme: ThemeConfig {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Background

/// The environment behind everything: a corner blob, a soft floor shade and the
/// ambient tint the clock is currently pushing.
struct TableBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.shellBackground

            RadialGradient(
                colors: [
                    theme.backgroundBlob.opacity(theme.backgroundBlobOpacity),
                    theme.backgroundBlob.opacity(theme.backgroundBlobOpacity * 0.47),
                    .clear
                ],
                center: UnitPoint(x: -0.04, y: -0.06),
                startRadius: 12,
                endRadius: 620
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(theme.backgroundShade)],
                startPoint: .top,
                endPoint: .bottom
            )

            theme.ambientTintColor

            AmbientSparkleLayer(accent: theme.accentColor, density: theme.usesDarkChrome ? 22 : 14)
        }
        .ignoresSafeArea()
    }
}

private struct SparkleStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.28
        let points = 4

        var path = Path()
        for index in 0..<(points * 2) {
            let angle = (Double(index) / Double(points * 2)) * 2 * .pi - .pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct AmbientSparkleLayer: View {
    let accent: Color
    var density: Int = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<density, id: \.self) { _ in
                    SparkleParticle(accent: accent, bounds: proxy.size)
                }
            }
        }
        .blur(radius: 0.4)
        .allowsHitTesting(false)
    }
}

private struct SparkleParticle: View {
    let accent: Color
    let bounds: CGSize

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.6
    @State private var size: CGFloat = 7
    @State private var rotation: Double = 0
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            SparkleStar()
                .fill(accent)
                .frame(width: size * 2.2, height: size * 2.2)
                .blur(radius: size * 0.5)
                .opacity(opacity * 0.6)

            SparkleStar()
                .fill(Color.white.opacity(0.85))
                .frame(width: size, height: size)
                .opacity(opacity)
        }
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .position(position)
        .onAppear {
            position = randomPoint()
            loopTask = Task { await runCycle() }
        }
        .onDisappear {
            loopTask?.cancel()
        }
    }

    private func randomPoint() -> CGPoint {
        CGPoint(x: .random(in: 0...max(bounds.width, 1)), y: .random(in: 0...max(bounds.height, 1)))
    }

    private func runCycle() async {
        try? await Task.sleep(nanoseconds: UInt64.random(in: 0...3_000_000_000))

        while !Task.isCancelled {
            size = .random(in: 5...11)
            rotation = .random(in: 0...45)
            let targetOpacity = Double.random(in: 0.15...0.3)
            let fadeInDuration = Double.random(in: 1.2...2.0)

            withAnimation(.easeOut(duration: fadeInDuration)) {
                opacity = targetOpacity
                scale = 1.1
            }

            // Let the fade-in finish before holding, so a new command never cuts it short.
            try? await Task.sleep(nanoseconds: UInt64((fadeInDuration + Double.random(in: 1.0...2.5)) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let fadeOutDuration = Double.random(in: 1.0...1.8)
            withAnimation(.easeIn(duration: fadeOutDuration)) {
                opacity = 0
                scale = 0.7
            }

            // And let the fade-out fully finish before relocating.
            try? await Task.sleep(nanoseconds: UInt64((fadeOutDuration + 0.1) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            position = randomPoint()
        }
    }
}

// MARK: - Chrome

/// Money that counts to its new value instead of snapping to it. The pace comes
/// from whoever animates `amount`.
struct CountingMoneyText: View, Animatable {
    var amount: Double

    // Interpolation runs off the main actor.
    nonisolated var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    var body: some View {
        Text(Int(amount.rounded()).money)
            .monospacedDigit()
    }
}

/// Which way the money went, and how that reads.
enum MoneyFlash {
    case gain
    case loss

    var ink: Color {
        switch self {
        case .gain: Color(hex: 0x1E7A36)
        case .loss: Color(hex: 0xD84A5A)
        }
    }

    var tint: Color {
        switch self {
        case .gain: Color(hex: 0x34C759, opacity: 0.30)
        case .loss: Color(hex: 0xD84A5A, opacity: 0.28)
        }
    }
}

/// The two-line money readout in the table header.
struct GlassPill: View {
    @Environment(\.theme) private var theme

    let title: String
    let amount: Int
    let systemImage: String
    /// Balance pills count, tint and tick when the number moves. Bet pills do not —
    /// placing a chip already has its own haptic, and doubling that up feels cheap.
    var reactsToChanges = false

    @State private var flash: MoneyFlash?
    @State private var flashTask: Task<Void, Never>?

    private let countDuration: TimeInterval = 0.32

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textDark)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)

                value
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .glassCapsule(flash?.tint ?? theme.pillTint)
        .animation(.easeOut(duration: 0.28), value: flash)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(amount.money)")
        .onChange(of: amount) { old, new in
            guard reactsToChanges, new != old else { return }
            react(rising: new > old)
        }
    }

    @ViewBuilder
    private var value: some View {
        if reactsToChanges {
            CountingMoneyText(amount: Double(amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(flash?.ink ?? theme.textDark)
                .animation(.easeOut(duration: countDuration), value: amount)
        } else {
            Text(amount.money)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textDark)
                .contentTransition(.numericText())
        }
    }

    private func react(rising: Bool) {
        flashTask?.cancel()
        flash = rising ? .gain : .loss
        FeedbackManager.moneyCount(duration: countDuration)

        flashTask = Task {
            // Long enough to register, short enough to stay out of the way.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            flash = nil
        }
    }
}

/// A round glass button — the hub grid, the back arrows, the close crosses.
struct GlassIconButton: View {
    @Environment(\.theme) private var theme

    let systemImage: String
    var size: CGFloat = 44
    var tint: Color?
    var showsGlow = false
    var accessibilityText: String
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackManager.buttonPress()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(theme.textDark)
                .frame(width: size, height: size)
                .glassCapsule(tint ?? theme.pillTint, interactive: true)
                .contentShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if showsGlow {
                        GlowDot(size: 8)
                            .padding(.top, 5)
                            .padding(.trailing, 6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }
}

/// The "something new" mark. Breathes rather than blinks — §7.
struct GlowDot: View {
    var size: CGFloat = 9
    var color = Color(hex: 0x00C7BE)

    @State private var isGlowing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.9), radius: size * 0.9)
            .opacity(isGlowing ? 0.95 : 0.4)
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: isGlowing)
            .onAppear { isGlowing = true }
            .accessibilityHidden(true)
    }
}

/// Back arrow plus a big title. Every screen behind the hub uses this.
struct ScreenHeader: View {
    @Environment(\.theme) private var theme

    let title: String
    var subtitle: String?
    var backSymbol = "arrow.left"
    var onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let onBack {
                    GlassIconButton(
                        systemImage: backSymbol,
                        size: 40,
                        tint: theme.glassTint,
                        accessibilityText: "Back",
                        action: onBack
                    )
                }

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .kerning(-0.7)
                    .foregroundStyle(theme.textDark)

                Spacer(minLength: 0)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }
        }
    }
}

struct SectionLabel: View {
    @Environment(\.theme) private var theme

    let text: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .kerning(1.1)
                .foregroundStyle(theme.textMid)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textMid)
            }
        }
    }
}

/// One of the hub's destination rows.
struct DestinationRow: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String?
    let systemImage: String
    var iconColor: Color?
    var background: Color?
    var showsGlow = false
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(iconColor ?? theme.textDark)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textDark)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textMid)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                if showsGlow {
                    GlowDot()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textMid)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(background ?? theme.glassTint, cornerRadius: 24, interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A locked shelf item: a silhouette wearing its own unlock condition.
struct SilhouetteTile: View {
    @Environment(\.theme) private var theme

    let caption: String
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.silhouette)
            .frame(width: width, height: height)
            .overlay {
                Text(caption)
                    .font(.system(size: width > 50 ? 9 : 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.textMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(0.5)
                    // Narrow tiles would otherwise break words mid-syllable.
                    .allowsTightening(true)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 4)
            }
    }
}

/// The lit glass lip each Game Room category sits on.
struct ShelfLedge: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 7)
            .shadow(color: .black.opacity(0.30), radius: 6, y: 6)
            .accessibilityHidden(true)
    }
}

/// A wide capsule action — Deal, Clear, Enter Fractured, and friends.
struct PrimaryAction: View {
    @Environment(\.theme) private var theme

    let title: String
    var systemImage: String?
    var tint: Color?
    var isEnabled = true
    var height: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackManager.buttonPress()
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(theme.textDark)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .glassCapsule(tint ?? theme.glassTint, interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

/// The quiet top-of-screen line. Never blocks anything, never asks for a tap.
struct ToastBanner: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0x00A79E))

            Text(message.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x14191F))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassSurface(Color.white.opacity(0.82), cornerRadius: 18)
        .shadow(color: .black.opacity(0.12), radius: 13, y: 8)
        .accessibilityAddTraits(.isStaticText)
    }
}
