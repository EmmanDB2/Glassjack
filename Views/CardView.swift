import SwiftUI

struct PlayingCardView: View {
    let card: Card
    let isFaceDown: Bool
    /// Overrides the suit-derived body colour. Used by the favourite card, which is
    /// cast in whichever glass the player picked.
    var tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.theme) private var theme

    private var cardShape: CardShape {
        CardShape(cornerRadius: 18)
    }

    var body: some View {
        ZStack {
            cardFace
                .opacity(isFaceDown ? 0 : 1)

            cardBack
                .opacity(isFaceDown ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFaceDown ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        .animation(.smooth(duration: 0.48), value: isFaceDown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFaceDown ? "Face down card" : card.accessibilityName)
    }

    private var cardFace: some View {
        ZStack {
            cardShape
                .fill(reduceTransparency ? fallbackFill : Color.white.opacity(0.18))
                .glassSurface(glassTint, in: cardShape)

            cardShape
                .strokeBorder(Color.clear, lineWidth: 1)
                .blendMode(.overlay)

            VStack(spacing: 0) {
                HStack {
                    CardCorner(rank: card.rank.symbol, suit: card.suit.glyph, color: inkColor)
                    Spacer(minLength: 0)
                }
                Spacer()
                HStack {
                    Spacer(minLength: 0)
                    CardCorner(rank: card.rank.symbol, suit: card.suit.glyph, color: inkColor)
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(8)

            CardPipContent(card: card, color: inkColor)
                .padding(16)
        }
        .clipShape(cardShape)
        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }

    private var cardBack: some View {
        ZStack {
            cardShape
                .fill(theme.cardBackTint)
                .glassSurface(theme.cardBackTint, in: cardShape)

            cardShape
                .strokeBorder(Color.clear, lineWidth: 1)
                .blendMode(.overlay)

            CardBackPattern(design: theme.cardBackDesign)
        }
        .clipShape(cardShape)
        .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
    }

    private var inkColor: Color {
        card.suit.isRed ? theme.redSuitColor : theme.blackSuitColor
    }

    private var fallbackFill: Color {
        card.suit.isRed ? Color(red: 1.0, green: 0.91, blue: 0.92) : Color(red: 0.94, green: 0.96, blue: 0.98)
    }

    /// Red cards carry a warmer body so a hand reads at a glance without needing
    /// to look at the pips.
    private var glassTint: Color {
        if let tint { return tint }
        return card.suit.isRed ? Color(hex: 0xE04A5A, opacity: 0.17) : Color(hex: 0x14191F, opacity: 0.055)
    }
}

struct CardShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: insetRect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct CardCorner: View {
    let rank: String
    let suit: String
    let color: Color

    var body: some View {
        VStack(spacing: -2) {
            Text(rank)
                .font(.system(size: 16, weight: .black, design: .rounded))
            Text(suit)
                .font(.system(size: 14, weight: .bold, design: .serif))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(width: 24, height: 34)
    }
}

private struct CardPipContent: View {
    let card: Card
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            if let count = card.rank.pipCount {
                ForEach(pipPositions(for: count), id: \.id) { pip in
                    Text(card.suit.glyph)
                        .font(.system(size: proxy.size.width * 0.22, weight: .black, design: .serif))
                        .foregroundStyle(color)
                        .rotationEffect(pip.rotated ? .degrees(180) : .zero)
                        .position(
                            x: proxy.size.width * pip.x,
                            y: proxy.size.height * pip.y
                        )
                }
            } else if card.rank == .ace {
                Text(card.suit.glyph)
                    .font(.system(size: proxy.size.width * 0.62, weight: .black, design: .serif))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 3) {
                    Text(card.rank.symbol)
                        .font(.system(size: proxy.size.width * 0.48, weight: .black, design: .rounded))
                    Text(card.suit.glyph)
                        .font(.system(size: proxy.size.width * 0.28, weight: .bold, design: .serif))
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func pipPositions(for count: Int) -> [PipPosition] {
        switch count {
        case 2:
            return [.topCenter, .bottomCenter]
        case 3:
            return [.topCenter, .center, .bottomCenter]
        case 4:
            return [.topLeft, .topRight, .bottomLeft, .bottomRight]
        case 5:
            return [.topLeft, .topRight, .center, .bottomLeft, .bottomRight]
        case 6:
            return [.topLeft, .topRight, .middleLeft, .middleRight, .bottomLeft, .bottomRight]
        case 7:
            return [.topLeft, .topRight, .upperCenter, .middleLeft, .middleRight, .bottomLeft, .bottomRight]
        case 8:
            return [.topLeft, .topRight, .upperCenter, .middleLeft, .middleRight, .lowerCenter, .bottomLeft, .bottomRight]
        case 9:
            return [.topLeft, .topRight, .upperCenter, .middleLeft, .center, .middleRight, .lowerCenter, .bottomLeft, .bottomRight]
        case 10:
            return [.topLeft, .topRight, .upperLeft, .upperRight, .middleLeft, .middleRight, .lowerLeft, .lowerRight, .bottomLeft, .bottomRight]
        default:
            return []
        }
    }
}

private struct PipPosition: Hashable {
    let x: CGFloat
    let y: CGFloat
    let rotated: Bool

    var id: String {
        "\(x)-\(y)-\(rotated)"
    }

    static let topLeft = PipPosition(x: 0.30, y: 0.18, rotated: false)
    static let topRight = PipPosition(x: 0.70, y: 0.18, rotated: false)
    static let topCenter = PipPosition(x: 0.50, y: 0.20, rotated: false)
    static let upperLeft = PipPosition(x: 0.30, y: 0.34, rotated: false)
    static let upperRight = PipPosition(x: 0.70, y: 0.34, rotated: false)
    static let upperCenter = PipPosition(x: 0.50, y: 0.34, rotated: false)
    static let middleLeft = PipPosition(x: 0.30, y: 0.50, rotated: false)
    static let center = PipPosition(x: 0.50, y: 0.50, rotated: false)
    static let middleRight = PipPosition(x: 0.70, y: 0.50, rotated: true)
    static let lowerLeft = PipPosition(x: 0.30, y: 0.66, rotated: true)
    static let lowerRight = PipPosition(x: 0.70, y: 0.66, rotated: true)
    static let lowerCenter = PipPosition(x: 0.50, y: 0.66, rotated: true)
    static let bottomLeft = PipPosition(x: 0.30, y: 0.82, rotated: true)
    static let bottomRight = PipPosition(x: 0.70, y: 0.82, rotated: true)
    static let bottomCenter = PipPosition(x: 0.50, y: 0.80, rotated: true)
}

/// What is printed on the back of a card, minus the tint underneath it. Shared by
/// the table and the Game Room shelf so a back looks the same wherever it is shown.
struct CardBackPattern: View {
    let design: CardBackDesign

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                switch design {
                case .lattice:
                    GeometricBackPattern()
                        .stroke(Color.white.opacity(0.48), lineWidth: max(0.9, size.width * 0.014))
                        .blendMode(.overlay)
                        .padding(size.width * 0.14)

                    Image(systemName: "diamond.fill")
                        .font(.system(size: size.width * 0.25, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .blendMode(.overlay)

                case .wordmark:
                    WordmarkBackPattern(size: size)

                case .rain:
                    RainBackPattern()
                        .stroke(
                            Color.white.opacity(0.42),
                            style: StrokeStyle(lineWidth: max(0.9, size.width * 0.022), lineCap: .round)
                        )
                        .blendMode(.overlay)
                        .padding(size.width * 0.10)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }
}

/// The wordmark as it reads on the table — name in the middle, sparkles scattered
/// around it — scaled to whatever the card is.
private struct WordmarkBackPattern: View {
    let size: CGSize

    /// Position as a fraction of the card, then size and opacity. Deliberately
    /// uneven so it reads as scattered rather than placed.
    private static let sparkles: [(x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = [
        (-0.29, -0.27, 0.15, 0.80),
        (0.28, -0.32, 0.10, 0.55),
        (0.31, 0.23, 0.13, 0.72),
        (-0.30, 0.29, 0.09, 0.52),
        (0.04, -0.41, 0.075, 0.45),
        (-0.08, 0.40, 0.075, 0.45)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.sparkles.enumerated()), id: \.offset) { _, sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: size.width * sparkle.scale, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(sparkle.opacity))
                    .blendMode(.overlay)
                    .offset(x: size.width * sparkle.x, y: size.height * sparkle.y)
            }

            // Solid rather than overlay-blended, so the name stays legible on both
            // the pale and the dark colourways.
            Text("Glassjack")
                .font(.system(size: size.width * 0.155, weight: .black, design: .rounded))
                .kerning(-size.width * 0.004)
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.12), radius: size.width * 0.02)
                .padding(.horizontal, size.width * 0.08)
        }
    }
}

/// Parallel streaks running off the top corner.
private struct RainBackPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.width / 4.5
        let slant = rect.height * 0.34
        var x = rect.minX - slant

        while x < rect.maxX + slant {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + slant, y: rect.minY))
            x += spacing
        }

        return path
    }
}

private struct GeometricBackPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows = 4
        let columns = 3
        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let center = CGPoint(
                    x: rect.minX + cellWidth * (CGFloat(column) + 0.5),
                    y: rect.minY + cellHeight * (CGFloat(row) + 0.5)
                )
                let radius = min(cellWidth, cellHeight) * 0.24
                path.move(to: CGPoint(x: center.x, y: center.y - radius))
                path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
                path.closeSubpath()
            }
        }

        return path
    }
}
