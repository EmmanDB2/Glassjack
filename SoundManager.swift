import AVFoundation
import UIKit

/// §10.1 — haptics carry the game feel, so every action gets its own pattern rather
/// than one shared buzz. All of it is gated behind the Settings toggle.
@MainActor
struct FeedbackManager {
    /// Mirrors `SettingsStore.hapticsEnabled`. Nothing fires while this is false.
    static var isEnabled = true

    static func play(for outcome: RoundOutcome) {
        switch outcome {
        case .win:
            notification(.success)
        case .blackjack:
            blackjackChime()
        case .push:
            impact(.light)
        case .loss:
            notification(.error)
        case .bust:
            bust()
        }
    }

    /// A card sliding across the felt — a light tick.
    static func cardSlide() {
        impact(.light)
    }

    /// A chip landing on the stack — a sharp tap.
    static func chipLand() {
        impact(.medium)
    }

    /// Soft and lingering: heavy, a beat, then light.
    static func blackjackChime() {
        notification(.success)
        impact(.heavy)
        delayedImpact(.light, after: 0.08)
    }

    /// Bust is a single muted tap — §5 asks for nothing judgemental.
    static func bust() {
        impact(.light)
    }

    /// A soft flutter while a number counts to its new value. Several taps spread
    /// across the count rather than one, so the change is felt as movement.
    static func moneyCount(duration: TimeInterval) {
        guard isEnabled else { return }
        Task { @MainActor in
            let ticks = 5
            let gap = duration / Double(ticks)
            for index in 0..<ticks {
                impact(.soft)
                guard index < ticks - 1 else { break }
                try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
            }
        }
    }

    /// Button press — a light selection click.
    static func buttonPress() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private static func delayedImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, after delay: TimeInterval) {
        guard isEnabled else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            impact(style)
        }
    }
}

enum SoundEffect: String, CaseIterable {
    case chipBet = "chip_bet"
    case cardDeal = "card_deal"
    case cardFlip = "card_flip"
    case win = "outcome_win"
    case blackjack = "outcome_blackjack"
    case push = "outcome_push"
    case loss = "outcome_loss"
    case bust = "outcome_bust"
    case shuffle = "shoe_shuffle"

    init(outcome: RoundOutcome) {
        switch outcome {
        case .blackjack: self = .blackjack
        case .win: self = .win
        case .push: self = .push
        case .loss: self = .loss
        case .bust: self = .bust
        }
    }

    var candidateFileNames: [String] {
        switch self {
        case .chipBet:
            [rawValue, "chip-lay-1", "chips-stack-1"]
        case .cardDeal:
            [rawValue, "card-slide-1", "card-place-1"]
        case .cardFlip:
            [rawValue, "card-place-2", "card-fan-1"]
        case .win:
            [rawValue, "chips-collide-1", "chips-stack-3"]
        case .blackjack:
            [rawValue, "chips-handle-6", "chips-stack-6"]
        case .push:
            [rawValue, "chip-lay-2", "card-place-3"]
        case .loss:
            [rawValue, "card-shove-1", "card-shove-2"]
        case .bust:
            [rawValue, "card-shove-4", "card-shove-3"]
        case .shuffle:
            [rawValue, "card-shuffle"]
        }
    }
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var isPrepared = false
    private let supportedExtensions = ["wav", "m4a", "mp3", "caf", "aiff"]

    private init() {}

    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        configureAudioSession()

        for effect in SoundEffect.allCases {
            guard players[effect] == nil, let url = url(for: effect) else { continue }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[effect] = player
            } catch {
                continue
            }
        }
    }

    func play(_ effect: SoundEffect) {
        if !isPrepared {
            prepare()
        }

        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
    }

    private func url(for effect: SoundEffect) -> URL? {
        for fileName in effect.candidateFileNames {
            for fileExtension in supportedExtensions {
                if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Sounds") {
                    return url
                }

                if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
                    return url
                }
            }
        }

        return nil
    }
}
