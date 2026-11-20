import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private let hotKey = HotKeyManager.shared
    private let controller = LyricsController.shared
    private var settingsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar.setup()
        hotKey.register()

        // Fallback Touch Bar for when no window is key (e.g. the Lyric Panel
        // is minimized). The panel's window-level bar takes precedence while
        // it is visible and focused.
        NSApp.touchBar = TouchBarController.shared.touchBar

        controller.onUpdate = { [weak self] in
            TouchBarController.shared.update()
            self?.statusBar.update(title: LyricsController.shared.currentLine)
        }
        controller.start()

        // Give first-time users immediate visible feedback (it is a menu-bar app).
        if !UserDefaults.standard.bool(forKey: "didShowLyricPanel") {
            UserDefaults.standard.set(true, forKey: "didShowLyricPanel")
            LyricPanelWindowController.shared.show()
        }

        settingsCancellable = AppSettings.shared.$showMenuBar
            .removeDuplicates()
            .sink { [weak self] visible in
                self?.statusBar.setVisible(visible)
            }

        // Spotify posts this distributed notification on track/state changes;
        // reacting to it makes lyric switches immediate instead of poll-bound.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyPlaybackChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        Task { @MainActor in await LyricsController.shared.refresh() }
    }
}
