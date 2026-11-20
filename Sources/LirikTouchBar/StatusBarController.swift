import AppKit

/// The always-available menu bar item. Shows the current lyric as a fallback
/// for macOS's restriction that only a frontmost app may draw to the Touch Bar.
@MainActor
final class StatusBarController: NSObject {
    private var item: NSStatusItem?
    private let menu = NSMenu()

    func setup() {
        buildMenu()
        ensureItem()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            ensureItem()
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    @MainActor
    func update(title: String) {
        guard let item else { return }
        let trimmed = String(title.prefix(45))
        item.button?.title = trimmed.isEmpty ? "♪" : trimmed
    }

    // MARK: - Private

    private func ensureItem() {
        guard item == nil else { return }
        let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        newItem.menu = menu
        item = newItem
        update(title: LyricsController.shared.currentLine)
    }

    private func buildMenu() {
        menu.addItem(withTitle: "Show Lyrics Panel", action: #selector(showPanel), keyEquivalent: "l")
            .target = self
        menu.addItem(withTitle: "Play / Pause", action: #selector(togglePlayback), keyEquivalent: "p")
            .target = self
        menu.addItem(withTitle: "Refresh Lyrics", action: #selector(refreshLyrics), keyEquivalent: "r")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Lirik", action: #selector(quitApp), keyEquivalent: "q")
            .target = self
    }

    @objc private func showPanel() {
        LyricPanelWindowController.shared.show()
    }

    @objc private func togglePlayback() {
        SpotifyService.shared.togglePlayback()
    }

    @objc private func refreshLyrics() {
        Task { @MainActor in await LyricsController.shared.refresh() }
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
