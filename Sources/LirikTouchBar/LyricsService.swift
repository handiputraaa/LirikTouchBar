import Foundation

/// Parses LRC / enhanced-LRC text into time-stamped lyric lines.
enum LRCParser {
    private static let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    private static let wordTimePattern = #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#

    static func parse(_ lrc: String) -> [LyricLine] {
        guard !lrc.isEmpty else { return [] }

        let timestampRegex = try? NSRegularExpression(pattern: timestampPattern)
        let wordTimeRegex = try? NSRegularExpression(pattern: wordTimePattern)
        guard let timestampRegex else { return [] }

        var lines: [LyricLine] = []

        for rawLine in lrc.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let fullRange = NSRange(line.startIndex..., in: line)
            let matches = timestampRegex.matches(in: line, range: fullRange)
            guard !matches.isEmpty else { continue }

            for (index, match) in matches.enumerated() {
                guard
                    let minuteRange = Range(match.range(at: 1), in: line),
                    let secondRange = Range(match.range(at: 2), in: line)
                else { continue }

                let minutes = Double(line[minuteRange]) ?? 0
                let seconds = Double(line[secondRange]) ?? 0

                var fraction = 0.0
                if let fractionRange = Range(match.range(at: 3), in: line),
                   let rawFraction = Double(line[fractionRange]) {
                    let divisor = pow(10.0, Double(line[fractionRange].count))
                    fraction = rawFraction / divisor
                }
                let time = minutes * 60 + seconds + fraction

                // Text runs from this timestamp up to the next one on the same line.
                let textStart = match.range(at: 0).upperBound
                let textEnd = index + 1 < matches.count
                    ? matches[index + 1].range(at: 0).lowerBound
                    : line.utf16.count

                guard textStart <= textEnd,
                      let swiftRange = Range(
                        NSRange(location: textStart, length: textEnd - textStart),
                        in: line
                      ) else { continue }

                var text = String(line[swiftRange])
                if let wordTimeRegex {
                    let textRange = NSRange(text.startIndex..., in: text)
                    text = wordTimeRegex.stringByReplacingMatches(
                        in: text, range: textRange, withTemplate: ""
                    )
                }
                text = text.trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}

/// Fetches synchronized lyrics from LRCLIB (free, no API key) and caches them locally.
final class LyricsService {
    static let shared = LyricsService()

    private var cache: [String: [LyricLine]] = [:]
    private let cacheURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return appSupport
            .appendingPathComponent("LirikTouchBar", isDirectory: true)
            .appendingPathComponent("lyrics-cache.json")
    }()

    private struct CacheEntry: Codable {
        let lines: [LyricLine]
    }

    init() {
        loadCache()
    }

    func lyrics(for track: Track) async -> [LyricLine] {
        let key = cacheKey(for: track)
        if let cached = cache[key] { return cached }

        // 1. Exact lookup with all metadata.
        var lines = await lookup(track, includeAlbum: true)

        // 2. Spotify and LRCLIB often disagree on album names — retry without it.
        if lines.isEmpty { lines = await lookup(track, includeAlbum: false) }

        // 3. Last resort: search and pick the closest matching track.
        if lines.isEmpty { lines = await search(track) }

        if !lines.isEmpty {
            cache[key] = lines
            saveCache()
        }
        return lines
    }

    // MARK: - Private

    private func makeRequest(_ url: URL?) -> URLRequest? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("LirikTouchBar/1.0 (macOS lyric mirroring utility)",
                         forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        return request
    }

    private func lookup(_ track: Track, includeAlbum: Bool) async -> [LyricLine] {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else { return [] }
        var items = [
            URLQueryItem(name: "track_name", value: track.name),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        if includeAlbum {
            items.append(URLQueryItem(name: "album_name", value: track.album))
        }
        components.queryItems = items
        guard let request = makeRequest(components.url),
              let response = await decode(request) else { return [] }
        return Self.lines(from: response)
    }

    private func search(_ track: Track) async -> [LyricLine] {
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.name) \(track.artist)")
        ]
        guard let request = makeRequest(components.url) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let results = try JSONDecoder().decode([LRCLIBResponse].self, from: data)
            guard let best = results.max(by: { Self.score($0, for: track) < Self.score($1, for: track) })
            else { return [] }
            DebugLog.write("LRCLIB search fallback picked '\(best.trackName ?? best.name ?? "?")'")
            return Self.lines(from: best)
        } catch {
            return []
        }
    }

    private func decode(_ request: URLRequest) async -> LRCLIBResponse? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(LRCLIBResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private static func lines(from response: LRCLIBResponse) -> [LyricLine] {
        LRCParser.parse(response.syncedLyrics ?? response.plainLyrics ?? "")
    }

    /// Picks the result closest to the playing track by title, artist, duration
    /// and whether synchronized lyrics are available.
    private static func score(_ result: LRCLIBResponse, for track: Track) -> Int {
        let normalize: (String) -> String = { value in
            value.lowercased().replacingOccurrences(
                of: "[^a-z0-9]", with: "", options: .regularExpression
            )
        }
        let resultName = normalize(result.trackName ?? result.name ?? "")
        let wantedName = normalize(track.name)
        let resultArtist = normalize(result.artistName ?? "")
        let wantedArtist = normalize(track.artist)

        var score = 0
        if resultName == wantedName { score += 100 }
        else if resultName.contains(wantedName) || wantedName.contains(resultName) { score += 50 }

        if resultArtist == wantedArtist { score += 50 }
        else if resultArtist.contains(wantedArtist) || wantedArtist.contains(resultArtist) { score += 20 }

        if result.syncedLyrics?.isEmpty == false { score += 25 }

        let difference = abs((result.duration ?? 0) - track.duration)
        score -= Int(min(difference, 60))
        return score
    }

    private func cacheKey(for track: Track) -> String {
        "\(track.artist.lowercased())|\(track.name.lowercased())|\(Int(track.duration.rounded()))"
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return }
        cache = decoded.mapValues { $0.lines }
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache.mapValues { CacheEntry(lines: $0) }) else {
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL)
        } catch {
            // Caching is best-effort; ignore failures.
        }
    }
}
