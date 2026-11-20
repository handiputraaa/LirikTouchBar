import Foundation

/// Reads the currently playing track from the local Spotify desktop app.
///
/// Uses Spotify's AppleScript interface, so no Spotify developer account,
/// client ID or redirect URI is required. The first call will prompt the user
/// to allow LirikTouchBar to control Spotify (Automation permission).
final class SpotifyService {
    static let shared = SpotifyService()

    /// Separator unlikely to occur inside a track title or artist name.
    private static let separator = "§§§"

    private static let script = """
    tell application "Spotify"
        if not running then return "stopped"
        if player state is stopped then return "stopped"
        set tr to current track
        if tr is missing value then return "stopped"
        set ps to "playing"
        if player state is paused then set ps to "paused"
        set n to (name of tr) as text
        set a to (artist of tr) as text
        set al to (album of tr) as text
        set u to (id of tr) as text
        set d to (duration of tr) as real
        set p to (player position) as real
        return ps & "\(separator)" & u & "\(separator)" & n & "\(separator)" & a & "\(separator)" & al & "\(separator)" & (d as text) & "\(separator)" & (p as text)
    end tell
    """

    /// Script used by the Touch Bar play/pause button.
    private static let toggleScript = """
    tell application "Spotify"
        if running then
            if player state is playing then
                pause
            else if player state is paused then
                play
            end if
        end if
    end tell
    """

    private let queue = DispatchQueue(label: "com.iseng.lirik.spotify", qos: .userInitiated)

    func fetchSnapshot() async -> SpotifySnapshot? {
        let script = Self.script
        return await withCheckedContinuation { continuation in
            queue.async {
                let output = Self.runAppleScript(script)
                let snapshot = Self.parse(output)
                if snapshot?.track == nil {
                    DebugLog.write("Spotify read: \(output.isEmpty ? "<empty>" : output)")
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    func togglePlayback() {
        let script = Self.toggleScript
        queue.async { _ = Self.runAppleScript(script) }
    }

    // MARK: - Private

    private static func runAppleScript(_ source: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]

        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return ""
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Accepts both "1.9552E+5" and locale-formatted "1,9552E+5".
    private static func parseNumber(_ string: String) -> Double? {
        Double(string.replacingOccurrences(of: ",", with: "."))
    }

    private static func parse(_ raw: String) -> SpotifySnapshot? {
        let parts = raw.components(separatedBy: separator)
        guard let first = parts.first,
              let state = PlaybackState(rawValue: first) else {
            return nil
        }

        guard state != .stopped, parts.count >= 7 else {
            return SpotifySnapshot(state: .stopped, track: nil, position: 0, receivedAt: Date())
        }

        // macOS formats AppleScript reals in the user's locale, e.g. "1,9552E+5"
        // in German. Normalize the decimal separator before converting.
        // Spotify reports `duration` in milliseconds but `player position` in seconds.
        var duration = parseNumber(parts[5]) ?? 0
        if duration > 10_000 { duration /= 1_000 }
        let position = parseNumber(parts[6]) ?? 0

        let track = Track(
            uri: parts[1],
            name: parts[2],
            artist: parts[3],
            album: parts[4],
            duration: duration
        )
        return SpotifySnapshot(
            state: state,
            track: track,
            position: position,
            receivedAt: Date()
        )
    }
}
