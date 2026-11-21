import Foundation
import Combine
import CoreGraphics

/// Keeps track of what Spotify is playing, loads matching lyrics, and computes
/// which lyric line should currently be displayed.
@MainActor
final class LyricsController: ObservableObject {
    static let shared = LyricsController()

    @Published var currentLine = "♪ Lirik is ready"
    @Published var upcomingLine = ""
    @Published var secondUpcomingLine = ""
    @Published var trackTitle = "Not playing"
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var statusMessage = "Waiting for Spotify…"
    @Published var hasLyrics = false

    /// Called whenever any displayable value changes (Touch Bar, menu bar, panel).
    var onUpdate: (() -> Void)?
    /// Called when the user returns after idle, so the Touch Bar can repaint.
    var onWake: (() -> Void)?

    private var wasIdle = false
    private var lastTickDate = Date()
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var lastSnapshot: SpotifySnapshot?
    private var lyrics: [LyricLine] = []
    private var loadedURI: String = ""
    private var isFetching = false
    private var lastDisplayedLine = ""

    private init() {}

    // MARK: - Lifecycle

    func start() {
        lastTickDate = Date()
        restartPollTimer()

        // A fast timer interpolates playback position between Spotify polls,
        // so lyric changes land within ~0.15s instead of waiting a full poll.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        settingsCancellable = AppSettings.shared.$refreshInterval
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in Task { @MainActor in self?.restartPollTimer() } }

        Task { @MainActor in await poll() }
    }

    func stop() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        pollTimer = nil
        tickTimer = nil
        settingsCancellable?.cancel()
        settingsCancellable = nil
    }

    func refresh() async {
        await poll(force: true)
    }

    // MARK: - Polling

    private func restartPollTimer() {
        pollTimer?.invalidate()
        let interval = AppSettings.shared.refreshInterval
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
    }

    private func poll(force: Bool = false) async {
        if isFetching && !force { return }

        guard let snapshot = await SpotifyService.shared.fetchSnapshot() else {
            statusMessage = "Cannot reach Spotify — check Automation permission"
            onUpdate?()
            return
        }
        lastSnapshot = snapshot

        let uri = snapshot.track?.uri ?? ""
        if uri != loadedURI {
            DebugLog.write("Track: \(snapshot.track?.name ?? "none") — \(snapshot.track?.artist ?? "") " +
                           "duration=\(snapshot.track?.duration ?? 0)s position=\(snapshot.position)s")
            loadedURI = uri
            lyrics = []
            upcomingLine = ""
            secondUpcomingLine = ""

            if let track = snapshot.track {
                isFetching = true
                statusMessage = "Looking up lyrics…"
                onUpdate?()
                let fetched = await LyricsService.shared.lyrics(for: track)
                isFetching = false
                DebugLog.write("Lyrics lookup '\(track.name)' -> \(fetched.count) lines")
                // Ignore a result that arrived after the user changed tracks.
                if loadedURI == uri { lyrics = fetched }
            }
        }

        apply(snapshot: snapshot)
    }

    private func tick() {
        let now = Date()
        let tickGap = now.timeIntervalSince(lastTickDate)
        lastTickDate = now

        // Detect the transition from "user away" to "user just touched the
        // keyboard/trackpad". CoreGraphics exposes this without extra permissions.
        let idle = Self.idleSeconds()
        var resumed = false
        if idle > 5 {
            wasIdle = true
        } else if wasIdle && idle < 1.5 {
            wasIdle = false
            resumed = true
        }

        // A large timer gap also means the process was suspended (system sleep).
        if resumed || tickGap > 2.0 {
            DebugLog.write("Idle wake (idle=\(Int(idle))s, gap=\(Int(tickGap))s) — forcing lyric refresh")
            onWake?()
            Task { @MainActor in await self.poll(force: true) }
        }

        guard let snapshot = lastSnapshot else { return }
        apply(snapshot: snapshot)
    }

    private static func idleSeconds() -> Double {
        let keyboard = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown
        )
        let mouse = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .leftMouseDown
        )
        return min(keyboard, mouse)
    }

    // MARK: - Rendering

    private func apply(snapshot: SpotifySnapshot) {
        trackTitle = snapshot.track?.name ?? "Not playing"
        artist = snapshot.track?.artist ?? ""
        isPlaying = snapshot.state == .playing

        // Extrapolate from the last known position while the track is playing.
        let position: TimeInterval = snapshot.state == .playing
            ? snapshot.position + Date().timeIntervalSince(snapshot.receivedAt)
            : snapshot.position
        let duration = snapshot.track?.duration ?? 0
        progress = duration > 0 ? min(max(position / duration, 0), 1) : 0

        if lyrics.isEmpty {
            hasLyrics = false
            currentLine = AppSettings.shared.fallbackText
            upcomingLine = ""
            secondUpcomingLine = ""
            if snapshot.track != nil && !isFetching {
                statusMessage = "No synced lyrics found"
            }
        } else {
            hasLyrics = true
            var index = 0
            for (i, line) in lyrics.enumerated() where line.time <= position + 0.12 { index = i }
            currentLine = lyrics[index].text
            upcomingLine = index + 1 < lyrics.count ? lyrics[index + 1].text : ""
            secondUpcomingLine = index + 2 < lyrics.count ? lyrics[index + 2].text : ""
            if !isFetching { statusMessage = "Synced · \(lyrics.count) lines" }
        }

        if currentLine != lastDisplayedLine {
            lastDisplayedLine = currentLine
            DebugLog.write("Now showing: \(currentLine)")
        }

        onUpdate?()
    }
}
