import AppKit
import SwiftUI

struct LyricPanelView: View {
    @ObservedObject private var state = LyricsController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: state.isPlaying ? "waveform" : "pause.circle")
                    .foregroundStyle(state.isPlaying ? .green : .secondary)
                Text(state.trackTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !state.artist.isEmpty {
                    Text("— \(state.artist)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            Text(state.currentLine)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !state.upcomingLine.isEmpty {
                Text(state.upcomingLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: state.progress)

            HStack {
                Text(state.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Preferences…") {
                    PreferencesWindowController.shared.show()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Text("⌥⌘L")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(width: 560, height: 190)
    }
}

/// A focusable window that owns the Touch Bar. macOS only displays an app's
/// Touch Bar while that app is frontmost, so focusing this panel is what puts
/// lyrics on the physical Touch Bar.
final class LyricPanelWindowController: NSWindowController, NSWindowDelegate {
    static let shared = LyricPanelWindowController()

    private let touchBarController = TouchBarController.shared

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 190),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lirik — Touch Bar Lyrics"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: LyricPanelView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func makeTouchBar() -> NSTouchBar? {
        touchBarController.touchBar
    }

    @MainActor
    func show() {
        touchBarController.update()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        window?.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidMiniaturize(_ notification: Notification) {
        // Harmless now: the system-modal lyric bar is independent of this window.
        DebugLog.write("Lyric Panel minimized — system Touch Bar stays active")
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        DebugLog.write("Lyric Panel restored")
        touchBarController.update()
    }
}
