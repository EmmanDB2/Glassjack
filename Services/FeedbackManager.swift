import AVFoundation
import UIKit

enum MusicTrack: String, CaseIterable {
    case track1 = "bgm_1"
    case track2 = "bgm_2"
    case track3 = "bgm_3"
    case track4 = "bgm_4"
}

@MainActor
final class MusicManager: NSObject {
    static let shared = MusicManager()

    private var player: AVAudioPlayer?
    private var playlist: [MusicTrack] = []
    private var currentIndex = 0
    private var isPrepared = false
    private let supportedExtensions = ["wav", "m4a", "mp3", "caf", "aiff"]

    var volume: Float = 0.4 {
        didSet { player?.volume = volume }
    }

    /// Mirrors the Settings "Ambient music" toggle.
    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    private override init() {
        super.init()
    }

    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        observeAppLifecycle()
        switchPlaylist(to: ThemeConfig.casinoFloor.musicTracks, shouldPreservePlayback: false)
    }

    func start() {
        guard isEnabled, !playlist.isEmpty else { return }
        if player == nil {
            loadTrack(at: currentIndex)
        }
        player?.play()
    }

    func stop() {
        player?.stop()
    }

    func switchPlaylist(to tracks: [MusicTrack]) {
        if !isPrepared {
            isPrepared = true
            observeAppLifecycle()
        }

        switchPlaylist(to: tracks, shouldPreservePlayback: player?.isPlaying == true)
    }

    private func loadTrack(at index: Int) {
        guard playlist.indices.contains(index), let url = url(for: playlist[index]) else { return }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            // single track loops forever; multiple tracks play through, then wrap
            newPlayer.numberOfLoops = playlist.count == 1 ? -1 : 0
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            player = newPlayer
        } catch {
            advanceToNextTrack()
        }
    }

    private func advanceToNextTrack() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        loadTrack(at: currentIndex)
        player?.play()
    }

    private func switchPlaylist(to tracks: [MusicTrack], shouldPreservePlayback: Bool) {
        player?.stop()
        player = nil
        playlist = tracks.filter { url(for: $0) != nil }
        currentIndex = 0

        guard !playlist.isEmpty else { return }

        loadTrack(at: currentIndex)
        if shouldPreservePlayback {
            player?.play()
        }
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.start() }
        }
    }

    private func url(for track: MusicTrack) -> URL? {
        for fileExtension in supportedExtensions {
            if let url = Bundle.main.url(forResource: track.rawValue, withExtension: fileExtension, subdirectory: "Sounds") {
                return url
            }
            if let url = Bundle.main.url(forResource: track.rawValue, withExtension: fileExtension) {
                return url
            }
        }
        return nil
    }
}

extension MusicManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.advanceToNextTrack()
        }
    }
}
