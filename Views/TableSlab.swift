import SwiftUI

/// A real table's outline: a straight dealer edge across the top, straight sides, and
/// a player edge bowed toward whoever is holding the phone.
struct TableSlabShape: Shape {
    var topCorner: CGFloat = 26

    /// The near edge is two wide elliptical corners that meet in the middle — the
    /// same construction as the design's `48% / 24%` radii. A single quad curve
    /// leaves a visible kink where the straight side turns into it; quarter
    /// ellipses join the sides tangentially, so the outline stays one stroke.
    func path(in rect: CGRect) -> Path {
        let radiusX = rect.width * 0.48
        let radiusY = min(rect.height * 0.19, 72)
        // Circle-to-Bézier constant: puts the control points where a cubic best
        // approximates a quarter ellipse.
        let kappa: CGFloat = 0.5523

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topCorner))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCorner, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCorner, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topCorner),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radiusY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - radiusX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - radiusY + radiusY * kappa),
            control2: CGPoint(x: rect.maxX - radiusX + radiusX * kappa, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radiusX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radiusY),
            control1: CGPoint(x: rect.minX + radiusX - radiusX * kappa, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - radiusY + radiusY * kappa)
        )
        path.closeSubpath()
        return path
    }
}

/// Text set along a circular arc, the way house rules are silk-screened onto felt.
/// SwiftUI has no text-on-path, so each character is measured, placed and rotated.
struct ArcText: View {
    let text: String
    /// Radius of the arc the baseline rides. Larger is flatter.
    var radius: CGFloat
    var size: CGFloat
    var weight: Font.Weight = .heavy
    var tracking: CGFloat = 2
    var color: Color
    /// `true` arches the middle upward, `false` dips it downward.
    var arched = true

    /// Where each character sits along the arc, and how wide its slot is, measured
    /// from the middle of the whole string.
    ///
    /// Positions come from cumulative prefixes of the real string rather than from
    /// each letter measured on its own. Measured alone, a letter gives its advance
    /// with no knowledge of its neighbours, so kerned pairs — "KJ", "PA", "TO" —
    /// come out too loose while everything else stays tight. That irregularity is
    /// what reads as badly spaced. A prefix carries the same layout the font would
    /// have used for the line, so the differences between prefixes are the real
    /// advances.
    private var placements: [(character: Character, centre: CGFloat, width: CGFloat)] {
        let font = UIFont.roundedSystemFont(ofSize: size, weight: weight)
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        // A sentinel keeps trailing spaces from being trimmed out of the measurement,
        // which would otherwise close up every gap between words.
        let sentinel = "|"
        let sentinelWidth = sentinel.size(withAttributes: [.font: font]).width
        let prefixes = (0...characters.count).map { count -> CGFloat in
            let slice = String(characters.prefix(count)) + sentinel
            return slice.size(withAttributes: [.font: font]).width - sentinelWidth
        }

        // Tracking belongs between letters, not after the last one — adding it there
        // too would push the whole string half a space off centre.
        let total = prefixes[characters.count] + tracking * CGFloat(characters.count - 1)

        return characters.indices.map { index in
            let advance = prefixes[index + 1] - prefixes[index]
            let centre = prefixes[index] + advance / 2 + tracking * CGFloat(index)
            return (characters[index], centre - total / 2, advance)
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(placements.enumerated()), id: \.offset) { _, item in
                let angle = item.centre / radius

                Text(String(item.character))
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .foregroundStyle(color)
                    // Pinned to the advance the measurement assumed, so a letter with
                    // lopsided side bearings still centres on its own slot.
                    .frame(width: item.width)
                    .rotationEffect(.radians(arched ? angle : -angle))
                    .offset(
                        x: radius * sin(angle),
                        y: arched
                            ? radius * (1 - cos(angle))
                            : -radius * (1 - cos(angle))
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.capitalized)
    }
}

extension UIFont {
    /// SF Rounded at a given weight — the UIKit half of `.system(design: .rounded)`,
    /// needed here only to measure advances for `ArcText`.
    static func roundedSystemFont(ofSize size: CGFloat, weight: Font.Weight) -> UIFont {
        let uiWeight: UIFont.Weight = switch weight {
        case .black: .black
        case .heavy: .heavy
        case .bold: .bold
        case .semibold: .semibold
        case .medium: .medium
        default: .regular
        }
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// The house rules etched into the glass. Deliberately low-contrast: this is
/// printing under the cards and chips, not an interface element.
struct TableMarkings: View {
    @Environment(\.theme) private var theme

    let width: CGFloat
    let bandTop: CGFloat
    let rules: (dealer: String, blackjack: String, insurance: String?)

    /// The middle line of the three, and the point the chips are tossed onto — the
    /// pile lands on the printing rather than in a circle beside it. The three lines
    /// are set wide apart so they carry the middle of the felt on their own, now
    /// that there is no circle under them.
    static func rulesCentre(_ bandTop: CGFloat) -> CGFloat {
        bandTop + 84
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            // The line the dealer's cards are pitched across.
            ArcLine(radius: width * 1.9, arched: false)
                .stroke(theme.primaryColor.opacity(0.30), lineWidth: 1.6)
                .frame(width: width * 0.9, height: 30)
                .position(x: width / 2, y: bandTop + 14)

            ArcText(text: rules.dealer, radius: width * 1.5, size: 9.5,
                    weight: .bold, tracking: 1.8,
                    color: theme.textMid.opacity(0.7), arched: false)
                .position(x: width / 2, y: TableMarkings.rulesCentre(bandTop) - 30)

            ArcText(text: rules.blackjack, radius: width * 1.35, size: 12,
                    weight: .black, tracking: 2.4,
                    color: theme.primaryColor.opacity(0.78))
                .position(x: width / 2, y: TableMarkings.rulesCentre(bandTop))

            if let insurance = rules.insurance {
                ArcText(text: insurance, radius: width * 1.55, size: 10,
                        weight: .bold, tracking: 2,
                        color: theme.textMid.opacity(0.68))
                    .position(x: width / 2, y: TableMarkings.rulesCentre(bandTop) + 30)
            }

        }
        .allowsHitTesting(false)
    }
}

/// A shallow arc through the middle of its frame, used for the pitch line.
private struct ArcLine: Shape {
    let radius: CGFloat
    let arched: Bool

    func path(in rect: CGRect) -> Path {
        let halfAngle = min(rect.width / 2 / radius, .pi / 2)
        var path = Path()

        let centreY = arched ? rect.midY + radius : rect.midY - radius
        let steps = 24
        for step in 0...steps {
            let angle = -halfAngle + (Double(step) / Double(steps)) * halfAngle * 2
            let point = CGPoint(
                x: rect.midX + radius * sin(angle),
                y: arched
                    ? centreY - radius * cos(angle)
                    : centreY + radius * cos(angle)
            )
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

/// The shoe as an object sitting on the table rather than a bar in the header —
/// §5 keeps the count visible, this just gives it somewhere to live.
struct ShoeTray: View {
    @Environment(\.theme) private var theme

    let count: String
    let fraction: Double

    private var clamped: Double { min(max(fraction, 0), 1) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.pillTint.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 1)
                    }

                // Three cards' worth of edges, receding into the tray.
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.85 - Double(index) * 0.21))
                            .frame(height: 5 - CGFloat(index))
                            .padding(.horizontal, 5 + CGFloat(index) * 2)
                    }
                }
                .padding(.top, 5)
            }
            .frame(width: 46, height: 34)

            HStack(spacing: 5) {
                Text(count)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textMid)
                    .contentTransition(.numericText())

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.6))
                        .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))

                    GeometryReader { proxy in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), theme.accentColor.opacity(0.75)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(3, (proxy.size.width - 3) * clamped),
                                height: max(3, proxy.size.height - 3)
                            )
                            .padding(1.5)
                    }
                }
                .frame(width: 44, height: 8)
                .animation(.snappy(duration: 0.2), value: clamped)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) cards left in the shoe")
    }
}

/// The name and running total for one side of the table, pinned to the felt.
struct FeltNameplate: View {
    @Environment(\.theme) private var theme

    let name: String
    let total: String
    var tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textDark)

            Text(total)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textDark)
                .contentTransition(.numericText())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(tint))
                .overlay(Capsule().strokeBorder(theme.hairline.opacity(0.8), lineWidth: 1))
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .glassCapsule(theme.glassTint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(total)")
    }
}
