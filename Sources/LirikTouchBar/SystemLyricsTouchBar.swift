import AppKit

/// The always-visible, system-modal lyric bar on the physical Touch Bar.
/// Two modes: lyrics (with transport controls) and system controls
/// (brightness / volume), since the full-width presentation hides Control Strip.
final class SystemLyricsTouchBar: NSObject, NSTouchBarDelegate {
    static let shared = SystemLyricsTouchBar()

    private enum Mode { case lyrics, controls }

    /// Usable lyric width after the transport buttons.
    private static let maxWidth: CGFloat = 560
    private static let maxFontSize: CGFloat = 16
    private static let minFontSize: CGFloat = 9

    private static let trayID = NSTouchBarItem.Identifier("com.iseng.lirik.controlstrip")
    private static let lyricID = NSTouchBarItem.Identifier("com.iseng.lirik.systemlyric")
    private static let previousID = NSTouchBarItem.Identifier("com.iseng.lirik.previous")
    private static let playID = NSTouchBarItem.Identifier("com.iseng.lirik.play")
    private static let nextID = NSTouchBarItem.Identifier("com.iseng.lirik.next")
    private static let controlsID = NSTouchBarItem.Identifier("com.iseng.lirik.controls")
    private static let closeID = NSTouchBarItem.Identifier("com.iseng.lirik.close")
    private static let brightnessID = NSTouchBarItem.Identifier("com.iseng.lirik.brightness")
    private static let volumeID = NSTouchBarItem.Identifier("com.iseng.lirik.volume")
    private static let muteID = NSTouchBarItem.Identifier("com.iseng.lirik.mute")
    private static let backID = NSTouchBarItem.Identifier("com.iseng.lirik.back")

    private var touchBar = NSTouchBar()
    private var mode: Mode = .lyrics

    private let label = NSTextField(labelWithString: "♪ Lirik")
    private let previousButton = NSButton()
    private let playButton = NSButton()
    private let nextButton = NSButton()
    private let controlsButton = NSButton()
    private let closeButton = NSButton()

    private let brightnessSlider = NSSlider()
    private let volumeSlider = NSSlider()
    private let muteButton = NSButton()
    private let backButton = NSButton()

    private var trayItem: NSCustomTouchBarItem?
    private var autoReturnTimer: Timer?
    private(set) var isPresented = false
    private var cachedPlayingState: Bool?
    private var cachedMutedState: Bool?

    private override init() {
        super.init()
        touchBar = makeBar()

        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 660).isActive = true

        configureButton(previousButton, symbol: "backward.fill",
                        description: "Previous track", action: #selector(previousTapped))
        configureButton(playButton, symbol: "play.fill",
                        description: "Play", action: #selector(playTapped))
        configureButton(nextButton, symbol: "forward.fill",
                        description: "Next track", action: #selector(nextTapped))
        configureButton(controlsButton, symbol: "slider.horizontal.3",
                        description: "System controls", action: #selector(showSystemControls))
        configureButton(closeButton, symbol: "xmark.circle.fill",
                        description: "Hide Lirik", action: #selector(closeTapped))
        configureButton(muteButton, symbol: "speaker.fill",
                        description: "Mute", action: #selector(muteTapped))
        configureButton(backButton, symbol: "music.note",
                        description: "Back to lyrics", action: #selector(showLyrics))

        configureSlider(brightnessSlider, action: #selector(brightnessChanged))
        configureSlider(volumeSlider, action: #selector(volumeChanged))
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
        present()
    }

    func present() {
        NSApp.unhide(nil)
        PrivateTouchBar.showsCloseBoxWhenFrontMost(false)
        PrivateTouchBar.present(touchBar, trayID: Self.trayID)
        isPresented = true
        DebugLog.write("System Touch Bar presented")
    }

    func hide() {
        PrivateTouchBar.dismiss(touchBar)
        isPresented = false
        DebugLog.write("System Touch Bar dismissed — frontmost app's bar restored")
    }

    /// Force a one-time repaint after the Touch Bar wakes or the track changes.
    func refresh() {
        guard isPresented else { return }
        touchBar = makeBar()
        present()
        DebugLog.write("System Touch Bar repainted")
    }

    func setText(_ text: String) {
        guard label.stringValue != text else { return }
        label.font = fittingFont(for: text)
        label.stringValue = text
        label.needsDisplay = true
        if isPresented {
            PrivateTouchBar.present(touchBar, trayID: Self.trayID)
        }
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
            item = NSCustomTouchBarItem(identifier: identifier); item.view = label
        case Self.previousID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = previousButton
        case Self.playID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = playButton
        case Self.nextID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = nextButton
        case Self.controlsID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = controlsButton
        case Self.closeID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = closeButton
        case Self.brightnessID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = brightnessSlider
        case Self.volumeID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = volumeSlider
        case Self.muteID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = muteButton
        case Self.backID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = backButton
        default:
            return nil
        }
        return item
    }

    // MARK: - Private

    private func makeBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        switch mode {
        case .lyrics:
            bar.defaultItemIdentifiers = [
                Self.lyricID, .flexibleSpace, Self.previousID,
                Self.playID, Self.nextID, Self.controlsID, Self.closeID
            ]
        case .controls:
            bar.defaultItemIdentifiers = [
                Self.brightnessID, Self.volumeID, Self.muteID,
                .flexibleSpace, Self.backID
            ]
        }
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

    private func configureSlider(_ slider: NSSlider, action: Selector) {
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = 0.5
        slider.target = self
        slider.action = action
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 120).isActive = true
    }

    // MARK: - Actions

    @objc private func playTapped() { SpotifyService.shared.togglePlayback() }
    @objc private func previousTapped() { SpotifyService.shared.previousTrack() }
    @objc private func nextTapped() { SpotifyService.shared.nextTrack() }

    @objc private func closeTapped() {
        DebugLog.write("Close tapped — hiding Lirik")
        hide()
        LyricPanelWindowController.shared.hidePanel()
        NSApp.hide(nil)
    }

    @objc private func showSystemControls() {
        mode = .controls
        refreshSystemControlValues()
        touchBar = makeBar()
        present()
        scheduleAutoReturn()
    }

    @objc private func showLyrics() {
        autoReturnTimer?.invalidate()
        autoReturnTimer = nil
        mode = .lyrics
        touchBar = makeBar()
        present()
    }

    private func scheduleAutoReturn() {
        autoReturnTimer?.invalidate()
        autoReturnTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.showLyrics() }
        }
    }

    private func refreshSystemControlValues() {
        if let brightness = SystemControls.brightness {
            brightnessSlider.doubleValue = Double(brightness)
        }
        let volume = SystemControls.volume
        if let volume { volumeSlider.doubleValue = Double(volume) }
        let muted = volume != nil && SystemControls.isMuted
        if cachedMutedState != muted {
            cachedMutedState = muted
            muteButton.image = NSImage(
                systemSymbolName: muted ? "speaker.slash.fill" : "speaker.fill",
                accessibilityDescription: muted ? "Unmute" : "Mute"
            )
        }
    }

    @objc private func brightnessChanged(_ sender: NSSlider) {
        SystemControls.brightness = Float(sender.doubleValue)
        scheduleAutoReturn()
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        SystemControls.volume = Float(sender.doubleValue)
        if sender.doubleValue > 0, SystemControls.isMuted { SystemControls.isMuted = false }
        scheduleAutoReturn()
    }

    @objc private func muteTapped() {
        SystemControls.isMuted.toggle()
        refreshSystemControlValues()
        scheduleAutoReturn()
    }
}

