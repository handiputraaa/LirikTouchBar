import AppKit

/// The always-visible, system-modal lyric bar on the physical Touch Bar.
/// Layout: lyric text on the left, transport controls on the right.
/// It is independent of which app is focused, and can be toggled from the
/// ♪ button in the Control Strip.
final class SystemLyricsTouchBar: NSObject, NSTouchBarDelegate {
    static let shared = SystemLyricsTouchBar()

    /// Usable lyric width after the close box and three transport buttons.
    private static let maxWidth: CGFloat = 560
    private static let maxFontSize: CGFloat = 16
    private static let minFontSize: CGFloat = 9

    private static let trayID = NSTouchBarItem.Identifier("com.iseng.lirik.controlstrip")
    private static let lyricID = NSTouchBarItem.Identifier("com.iseng.lirik.systemlyric")
    private static let previousID = NSTouchBarItem.Identifier("com.iseng.lirik.previous")
    private static let playID = NSTouchBarItem.Identifier("com.iseng.lirik.play")
    private static let nextID = NSTouchBarItem.Identifier("com.iseng.lirik.next")

    private var touchBar = NSTouchBar()
    private let label = NSTextField(labelWithString: "♪ Lirik")
    private let previousButton = NSButton()
    private let playButton = NSButton()
    private let nextButton = NSButton()

    private var trayItem: NSCustomTouchBarItem?
    private(set) var isPresented = false
    private var cachedPlayingState: Bool?

    private override init() {
        super.init()

        touchBar = makeBar()

        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        // Leave room for the three transport buttons on a 13" Touch Bar.
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 660).isActive = true

        configureButton(previousButton, symbol: "backward.fill",
                        description: "Previous track", action: #selector(previousTapped))
        configureButton(playButton, symbol: "play.fill",
                        description: "Play", action: #selector(playTapped))
        configureButton(nextButton, symbol: "forward.fill",
                        description: "Next track", action: #selector(nextTapped))
    }

    /// Call once at launch. Installs the Control Strip button and presents the bar.
    func install() {
        let item = NSCustomTouchBarItem(identifier: Self.trayID)
        let image = NSImage(systemSymbolName: "music.note",
                            accessibilityDescription: "Lirik lyrics") ?? NSImage()
        item.view = NSButton(image: image, target: self, action: #selector(toggle))
        trayItem = item

        PrivateTouchBar.addSystemTrayItem(item)
        PrivateTouchBar.setControlStripPresence(Self.trayID, visible: true)
        PrivateTouchBar.showsCloseBoxWhenFrontMost(true)
        present()
    }

    func present() {
        PrivateTouchBar.present(touchBar, trayID: Self.trayID)
        isPresented = true
        DebugLog.write("System Touch Bar presented")
    }

    func hide() {
        PrivateTouchBar.minimize(touchBar)
        isPresented = false
        DebugLog.write("System Touch Bar minimized")
    }

    /// Force a one-time repaint after the Touch Bar wakes from idle.
    /// Rebuilding here is fine because it happens only on wake, not per line.
    func refresh() {
        guard isPresented else { return }
        touchBar = makeBar()
        PrivateTouchBar.present(touchBar, trayID: Self.trayID)
        DebugLog.write("System Touch Bar repainted after idle")
    }

    func setText(_ text: String) {
        guard label.stringValue != text else { return }
        // Update only the label in place. Rebuilding or re-presenting the bar
        // here would recreate the transport items and make them flicker.
        label.font = fittingFont(for: text)
        label.stringValue = text
        label.needsDisplay = true
    }

    func setPlaying(_ playing: Bool) {
        guard cachedPlayingState != playing else { return }
        cachedPlayingState = playing
        playButton.image = NSImage(
            systemSymbolName: playing ? "pause.fill" : "play.fill",
            accessibilityDescription: playing ? "Pause" : "Play"
        )
    }

    @objc func toggle() {
        isPresented ? hide() : present()
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item: NSCustomTouchBarItem
        switch identifier {
        case Self.lyricID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = label
        case Self.previousID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = previousButton
        case Self.playID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = playButton
        case Self.nextID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = nextButton
        default:
            return nil
        }
        return item
    }

    // MARK: - Private

    private func makeBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        // flexibleSpace absorbs all slack, pinning the transport buttons to
        // the right edge while the lyric stays anchored at the left.
        bar.defaultItemIdentifiers = [
            Self.lyricID,
            .flexibleSpace,
            Self.previousID,
            Self.playID,
            Self.nextID
        ]
        // No principal item: that would center the lyric. Leaving it unset
        // keeps the lyric flush left, next to the close (X) box.
        bar.principalItemIdentifier = nil
        return bar
    }

    /// Shrink the font until the whole line fits, instead of truncating it.
    private func fittingFont(for text: String) -> NSFont {
        var size = Self.maxFontSize
        while size > Self.minFontSize {
            let font = NSFont.systemFont(ofSize: size, weight: .medium)
            let width = (text as NSString).size(withAttributes: [.font: font]).width
            if width <= Self.maxWidth - 8 { return font }
            size -= 1
        }
        return NSFont.systemFont(ofSize: Self.minFontSize, weight: .medium)
    }

    private func configureButton(_ button: NSButton, symbol: String,
                                 description: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
    }

    @objc private func playTapped() {
        SpotifyService.shared.togglePlayback()
    }

    @objc private func previousTapped() {
        SpotifyService.shared.previousTrack()
    }

    @objc private func nextTapped() {
        SpotifyService.shared.nextTrack()
    }
}
