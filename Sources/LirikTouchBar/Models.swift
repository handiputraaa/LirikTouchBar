import Foundation

// MARK: - Spotify

enum PlaybackState: String {
    case playing
    case paused
    case stopped
}

struct Track: Equatable {
    let uri: String
    let name: String
    let artist: String
    let album: String
    /// Track length in seconds.
    let duration: TimeInterval
}

struct SpotifySnapshot: Equatable {
    let state: PlaybackState
    let track: Track?
    /// Playback position in seconds, as reported by Spotify.
    let position: TimeInterval
    /// When this snapshot was taken, used to interpolate a smooth position.
    let receivedAt: Date
}

// MARK: - Lyrics

struct LyricLine: Codable, Equatable {
    let time: TimeInterval
    let text: String
}

struct LRCLIBResponse: Decodable {
    let id: Int?
    let name: String?
    let trackName: String?
    let artist: String?
    let artistName: String?
    let album: String?
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
}
