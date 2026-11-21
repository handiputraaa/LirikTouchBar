import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBarController()
    private let hotKey = HotKeyManager.shared
    private let controller = LyricsController.shared
    private var settingsCancellable: AnyCancellable?
    private var backgroundActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap from throttling sync timers while Lirik is in the background.
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "Keep Touch Bar lyrics in sync while Spotify plays"
        )

        statusBar.setup()
        hotKey.register()

        // System-modal Touch Bar: stays on the physical Touch Bar regardless
        // of which app is frontmost or whether the panel is minimized.
        SystemLyricsTouchBar.shared.install()

        controller.onWake = {
            SystemLyricsTouchBar.shared.refresh()
        }

        controller.onUpdate = { [weak self] in
            TouchBarController.shared.update()
            self?.statusBar.update(title: LyricsController.shared.currentLine)
            SystemLyricsTouchBar.shared.setText(LyricsController.shared.currentLine)
            SystemLyricsTouchBar.shared.setPlaying(LyricsController.shared.isPlaying)
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
        if let backgroundActivity {
            ProcessInfo.processInfo.endActivity(backgroundActivity)
            self.backgroundActivity = nil
        }
    }

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        Task { @MainActor in await LyricsController.shared.refresh() }
    }
}
