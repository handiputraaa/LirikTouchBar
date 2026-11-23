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
    /// Called when the playing track changes, so the Touch Bar fully refreshes.
    var onTrackChange: (() -> Void)?

    private var wasIdle = false
    private var lastTickDate = Date()
    private var lastWakeDate = Date.distantPast
    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var romanizeCancellable: AnyCancellable?
    private var lastSnapshot: SpotifySnapshot?
    private var lyrics: [LyricLine] = []
    private var loadedTrackKey: String = ""
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

        romanizeCancellable = Publishers.CombineLatest(
            AppSettings.shared.$romanizeKorean,
            AppSettings.shared.$romanizeDigits
        )
        .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
        .dropFirst()
        .sink { [weak self] _ in Task { @MainActor in self?.tick() } }

        Task { @MainActor in await poll() }
    }

    func stop() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        pollTimer = nil
        tickTimer = nil
        settingsCancellable?.cancel()
        settingsCancellable = nil
        romanizeCancellable?.cancel()
        romanizeCancellable = nil
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

        // Spotify can briefly report the new URI with the OLD title/artist
        // during a transition. Keying on all three avoids missing that change.
        let key = [
            snapshot.track?.uri ?? "",
            snapshot.track?.name ?? "",
            snapshot.track?.artist ?? ""
        ].joined(separator: "|")
        let trackChanged = key != loadedTrackKey
        if trackChanged {
            DebugLog.write("Track: \(snapshot.track?.name ?? "none") — \(snapshot.track?.artist ?? "") " +
                           "duration=\(snapshot.track?.duration ?? 0)s position=\(snapshot.position)s")
            loadedTrackKey = key
            lyrics = []
            upcomingLine = ""
            secondUpcomingLine = ""

            if let track = snapshot.track {
                isFetching = true
                statusMessage = "Looking up lyrics…"
                onUpdate?()
                DebugLog.write("Fetching lyrics for '\(track.name)'…")
                let fetched = await LyricsService.shared.lyrics(for: track)
                DebugLog.write("Fetch returned \(fetched.count) lines")
                isFetching = false
                // Ignore a result that arrived after the user changed tracks.
                if loadedTrackKey == key { lyrics = fetched }
            }
        }

        apply(snapshot: snapshot)
        if trackChanged { onTrackChange?() }
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
        // Throttle repaints — rebuilding the system bar too often makes the
        // transport buttons appear to blink.
        if (resumed || tickGap > 2.0) && now.timeIntervalSince(lastWakeDate) > 5 {
            lastWakeDate = now
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

    /// Converts Hangul to roman letters when the preference is enabled.
    /// Uses a dedicated Revised Romanization converter (`KoreanRomanizer`).
    private func displayText(_ raw: String) -> String {
        guard AppSettings.shared.romanizeKorean,
              raw.unicodeScalars.contains(where: { scalar in
                  let value = scalar.value
                  return (0xAC00...0xD7A3).contains(value) ||   // Hangul syllables
                         (0x1100...0x11FF).contains(value) ||   // Hangul jamo
                         (0x3130...0x318F).contains(value)      // compatibility jamo
              }) else { return raw }

        return KoreanRomanizer.romanize(raw, spellOutDigits: AppSettings.shared.romanizeDigits)
    }

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
            currentLine = displayText(AppSettings.shared.fallbackText)
            upcomingLine = ""
            secondUpcomingLine = ""
            if snapshot.track == nil {
                statusMessage = "Waiting for Spotify…"
            } else if !isFetching {
                statusMessage = "No synced lyrics found"
            }
        } else {
            hasLyrics = true
            var index = 0
            for (i, line) in lyrics.enumerated() where line.time <= position + 0.12 { index = i }
            currentLine = displayText(lyrics[index].text)
            upcomingLine = index + 1 < lyrics.count ? displayText(lyrics[index + 1].text) : ""
            secondUpcomingLine = index + 2 < lyrics.count ? displayText(lyrics[index + 2].text) : ""
            if !isFetching { statusMessage = "Synced · \(lyrics.count) lines" }
        }

        if currentLine != lastDisplayedLine {
            lastDisplayedLine = currentLine
            DebugLog.write("Now showing: \(currentLine)")
        }

        onUpdate?()
    }
}
