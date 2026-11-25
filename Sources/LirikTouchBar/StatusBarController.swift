import AppKit

/// The menu-bar app icon. Clicking it opens the controls and preferences.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private let menu = NSMenu()
    private var touchBarToggleItem: NSMenuItem?

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

    /// The current lyric is no longer printed in the menu bar; it is shown as
    /// a tooltip on the icon instead, keeping the top bar clean.
    func update(title: String) {
        guard let item else { return }
        item.button?.toolTip = "Lirik — \(title)"
    }

    // MARK: - Private

    private func ensureItem() {
        guard item == nil else { return }
        let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let image = NSImage(systemSymbolName: "music.note",
                            accessibilityDescription: "Lirik")
        image?.isTemplate = true
        newItem.button?.image = image
        newItem.button?.title = ""
        newItem.button?.toolTip = "Lirik — lyrics on Touch Bar"

        newItem.menu = menu
        item = newItem
    }

    private func buildMenu() {
        menu.delegate = self

        menu.addItem(withTitle: "Show Lyrics Panel", action: #selector(showPanel), keyEquivalent: "l")
            .target = self

        let toggle = menu.addItem(withTitle: "Hide Touch Bar Lyrics",
                                  action: #selector(toggleTouchBarLyrics),
                                  keyEquivalent: "t")
        toggle.target = self
        touchBarToggleItem = toggle

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Play / Pause", action: #selector(togglePlayback), keyEquivalent: "p")
            .target = self
        menu.addItem(withTitle: "Refresh Lyrics", action: #selector(refreshLyrics), keyEquivalent: "r")
            .target = self
        menu.addItem(withTitle: "System Controls (Fn)", action: #selector(showFnControls), keyEquivalent: "f")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Lirik", action: #selector(quitApp), keyEquivalent: "q")
            .target = self
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        touchBarToggleItem?.title = SystemLyricsTouchBar.shared.isPresented
            ? "Hide Touch Bar Lyrics"
            : "Show Touch Bar Lyrics"
    }

    // MARK: - Actions

    // Defer every action to the next run-loop turn: NSStatusBar menu actions run
    // while the menu is still tracking, and touching the private system-modal
    // Touch Bar API during that window can block AppKit and freeze the app.
    @objc private func showPanel() {
        Task { @MainActor in LyricPanelWindowController.shared.show() }
    }

    @objc private func toggleTouchBarLyrics() {
        Task { @MainActor in SystemLyricsTouchBar.shared.toggle() }
    }

    @objc private func togglePlayback() {
        SpotifyService.shared.togglePlayback()
    }

    @objc private func refreshLyrics() {
        Task { @MainActor in await LyricsController.shared.refresh() }
    }

    @objc private func showFnControls() {
        Task { @MainActor in SystemLyricsTouchBar.shared.showFunctionKeys() }
    }

    @objc private func openPreferences() {
        Task { @MainActor in PreferencesWindowController.shared.show() }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
