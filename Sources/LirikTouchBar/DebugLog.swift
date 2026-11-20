import Foundation

/// Small append-only diagnostic log. Useful for verifying that Spotify reads,
/// lyric lookups and sync are working without attaching a debugger.
enum DebugLog {
    private static let url: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return logs.appendingPathComponent("Logs/LirikTouchBar.log", isDirectory: false)
    }()

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date()))  \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        let fileManager = FileManager.default
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > 200_000 {
            try? data.write(to: url) // rotate: keep the log bounded
            return
        }

        if fileManager.fileExists(atPath: url.path),
           let handle = FileHandle(forWritingAtPath: url.path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }
}
