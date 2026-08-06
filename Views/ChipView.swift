import SwiftUI

/// §4 — a clear glass bead with a flat top, in the manner of vase-filler pebbles.
///
/// The volume comes from stacking what actually happens in a lump of coloured
/// glass: the body goes pale where light passes straight through and saturates
/// toward the rim where the glass is thickest, the far edge darkens, a caustic
/// crescent glows where light bounces back up through the bottom, and a hard
/// specular hot-spot sits under a broader sheen. The denomination is engraved
/// rather than printed.
///
/// One light source, up and to the left, and every layer agrees with it.
struct GlassBead: View {
    let color: Color
    let label: String
    var size: CGFloat = 54

    var body: some View {
        // Deliberately no `glassEffect` and no rim stroke: both draw a bright ring
        // around the edge, and a bead is defined by its own shading, not an outline.
        stack
            .background(Circle().fill(color.opacity(0.26)))
            .frame(width: size, height: size)
            // Glass throws a little of its own colour onto the felt beneath it.
            .shadow(color: color.opacity(0.50), radius: size * 0.14, y: size * 0.10)
            .shadow(color: .black.opacity(0.16), radius: size * 0.05, y: size * 0.04)
            .contentShape(Circle())
    }

    private var stack: some View {
        ZStack {
            glassBody
            farEdge
            caustic
            sheen
            hotSpot
            engravedLabel
        }
    }

    /// Pale where the light comes through, full-strength toward the rim.
    private var glassBody: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.40),
                        color.opacity(0.86),
                        color
                    ],
                    center: UnitPoint(x: 0.36, y: 0.32),
                    startRadius: size * 0.03,
                    endRadius: size * 0.60
                )
            )
    }

    /// Thick glass on the side away from the light, softened so it reads as depth
    /// rather than a drawn line.
    private var farEdge: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [Color.black.opacity(0.30), Color.black.opacity(0.04)],
                    startPoint: .bottomTrailing,
                    endPoint: .topLeading
                ),
                lineWidth: size * 0.11
            )
            .blur(radius: size * 0.05)
    }

    /// Light that has passed through the bead and bounced back off the surface
    /// underneath — the giveaway that a pebble is translucent rather than opaque.
    private var caustic: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.60, height: size * 0.30)
            .offset(y: size * 0.23)
            .blur(radius: size * 0.06)
    }

    /// The broad soft highlight across the dome.
    private var sheen: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.60), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.72, height: size * 0.44)
            .rotationEffect(.degrees(-24))
            .offset(x: -size * 0.05, y: -size * 0.19)
            .blur(radius: size * 0.045)
    }

    /// The small hard glint. Kept tight — this is what sells glass over plastic.
    private var hotSpot: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.95), Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.11
                )
            )
            .frame(width: size * 0.28, height: size * 0.18)
            .rotationEffect(.degrees(-20))
            .offset(x: -size * 0.16, y: -size * 0.23)
    }

    private var labelFontSize: CGFloat {
        label.count > 3 ? size * 0.22 : size * 0.24
    }

    /// Cut into the glass rather than printed on it: dark below, light above.
    private var engravedLabel: some View {
        let cutBlur: CGFloat = size * 0.012
        let cutDrop: CGFloat = size * 0.018
        let lift: CGFloat = size * 0.012

        return Text(label)
            .font(.system(size: labelFontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.94))
            .shadow(color: Color.black.opacity(0.32), radius: cutBlur, y: cutDrop)
            .shadow(color: Color.white.opacity(0.30), radius: 0, y: -lift)
    }
}

/// The tappable version in the betting dock.
struct ChipButton: View {
    let denomination: ChipDenomination
    var size: CGFloat = 54
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassBead(color: denomination.color, label: denomination.label, size: size)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel("Bet \(denomination.value.money)")
    }
}

// MARK: - The bet on the felt

/// §10.2 — the chip toss.
///
/// `Curves.bounceOut` on its own feels floaty because one easing drives both axes.
/// A thrown object separates them: gravity only acts on Y. So a single linear
/// 0→1 progress drives the modifier, and the shape of each axis is computed here.
private struct TossEffect: ViewModifier, Animatable {
    var progress: Double
    let fromX: CGFloat

    /// The peak lands a little under halfway, matching the toss in the spec.
    private let apex = 0.46
    private let launchHeight: CGFloat = 190
    private let apexHeight: CGFloat = -54

    // Animation interpolation runs off the main actor.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(x: x, y: y)
    }

    /// X: smooth horizontal drift that decelerates the whole way — no gravity here.
    private var x: CGFloat {
        let eased = 1 - pow(1 - progress, 3)
        return fromX * (1 - eased)
    }

    /// Y: leaves the hand fast and slows into the peak, then accelerates
    /// quadratically into the table for a single definitive landing.
    private var y: CGFloat {
        if progress <= apex {
            let t = progress / apex
            let decelerated = 1 - pow(1 - t, 2)
            return launchHeight + (apexHeight - launchHeight) * decelerated
        }
        let t = (progress - apex) / (1 - apex)
        return apexHeight - apexHeight * (t * t)
    }

    /// Perspective shrink, applied during the rise only.
    private var scale: CGFloat {
        guard progress <= apex else { return 1 }
        return 1.45 + (1 - 1.45) * (progress / apex)
    }
}

private struct TossedChip: View {
    let chip: PlacedChip
    let beadSize: CGFloat

    @State private var progress: Double = 0

    var body: some View {
        GlassBead(color: chip.color, label: chip.label, size: beadSize)
            .rotationEffect(.degrees(chip.rotation))
            .modifier(TossEffect(progress: progress, fromX: chip.fromX))
            .onAppear {
                // Linear, because the modifier owns the shape of the arc.
                withAnimation(.linear(duration: 0.52)) {
                    progress = 1
                }
            }
    }
}

/// The bet as it sits on the table: a loose pile of glass beads with the total
/// underneath. Tapping the total clears the bet.
struct BetChipStack: View {
    @Environment(\.theme) private var theme

    let chips: [PlacedChip]
    let total: Int
    /// Only true while betting — once cards are out, the wager is committed.
    let isClearable: Bool
    /// Non-nil once the round has settled and the bet is leaving the table.
    let sweep: ChipSweep?
    let onClear: () -> Void

    /// Smaller than the ones in the dock, so a pile of them still fits the felt.
    private let beadSize: CGFloat = 42

    /// The pile is drawn inside a box that never changes size, so however many
    /// chips land, nothing around them moves. Chips overflow this box on purpose —
    /// it is a layout footprint, not a clip, and it is kept small enough to fit
    /// the felt without squeezing the hands either side of it.
    private let footprint = CGSize(width: 132, height: 82)

    var body: some View {
        // Deliberately not inside a GlassEffectContainer: fusing overlapping
        // beads turns the pile into one big blob instead of loose chips.
        ZStack {
            ForEach(chips) { chip in
                TossedChip(chip: chip, beadSize: beadSize)
                    .offset(chip.pileOffset)
                    .zIndex(Double(chip.index))
            }
        }
        .frame(width: footprint.width, height: footprint.height)
        .animation(.snappy(duration: 0.3), value: chips.count)
        // The total sits beside the pile rather than beneath it. Hung off the
        // trailing edge as an overlay so the pile keeps the middle of the felt.
        .overlay(alignment: .trailing) {
            totalPill
                .fixedSize()
                .alignmentGuide(.trailing) { $0[.leading] - 10 }
        }
        // The whole bet leaves together — chips and total alike.
        .offset(y: sweep?.travel ?? 0)
        .scaleEffect(sweep == nil ? 1 : 0.88)
        .opacity(sweep == nil ? 1 : 0)
    }

    private var totalPill: some View {
        Button {
            FeedbackManager.buttonPress()
            onClear()
        } label: {
            HStack(spacing: 5) {
                Text(total.money)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textDark)
                if isClearable {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textMid)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .glassCapsule(theme.glassTint, interactive: isClearable)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isClearable)
        .accessibilityLabel(isClearable ? "Clear bet of \(total.money)" : "Bet \(total.money)")
    }
}

#Preview("Glass beads") {
    ZStack {
        TableBackground()
        VStack(spacing: 30) {
            HStack(spacing: 12) {
                ForEach(ChipDenomination.casinoFloorSet) { denomination in
                    GlassBead(color: denomination.color, label: denomination.label)
                }
            }
            HStack(spacing: 12) {
                ForEach(ChipDenomination.highRollerSet) { denomination in
                    GlassBead(color: denomination.color, label: denomination.label, size: 46)
                }
            }
        }
    }
}
