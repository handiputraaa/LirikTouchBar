import AppKit

/// The always-visible, system-modal lyric bar on the physical Touch Bar.
/// Two modes: lyrics (with transport controls) and system controls
/// (brightness / volume), since the full-width presentation hides Control Strip.
final class SystemLyricsTouchBar: NSObject, NSTouchBarDelegate {
    static let shared = SystemLyricsTouchBar()

    private enum Mode { case lyrics, controls }

    /// Usable lyric width after the transport buttons.
    private static let maxWidth: CGFloat = 440
    private static let maxFontSize: CGFloat = 16
    private static let minFontSize: CGFloat = 9

    private static let trayID = NSTouchBarItem.Identifier("com.iseng.lirik.controlstrip")
    private static let lyricID = NSTouchBarItem.Identifier("com.iseng.lirik.systemlyric")
    private static let previousID = NSTouchBarItem.Identifier("com.iseng.lirik.previous")
    private static let playID = NSTouchBarItem.Identifier("com.iseng.lirik.play")
    private static let nextID = NSTouchBarItem.Identifier("com.iseng.lirik.next")
    private static let seekBackID = NSTouchBarItem.Identifier("com.iseng.lirik.seekback")
    private static let seekForwardID = NSTouchBarItem.Identifier("com.iseng.lirik.seekforward")
    private static let controlsID = NSTouchBarItem.Identifier("com.iseng.lirik.controls")
    private static let closeID = NSTouchBarItem.Identifier("com.iseng.lirik.close")
    private static let brightnessID = NSTouchBarItem.Identifier("com.iseng.lirik.brightness")
    private static let volumeID = NSTouchBarItem.Identifier("com.iseng.lirik.volume")
    private static let muteID = NSTouchBarItem.Identifier("com.iseng.lirik.mute")
    private static let keyboardID = NSTouchBarItem.Identifier("com.iseng.lirik.keyboard")
    private static let nativeID = NSTouchBarItem.Identifier("com.iseng.lirik.native")
    private static let backID = NSTouchBarItem.Identifier("com.iseng.lirik.back")

    private var touchBar = NSTouchBar()
    private var mode: Mode = .lyrics

    private let label = NSTextField(labelWithString: "♪ Lirik")
    private let previousButton = NSButton()
    private let playButton = NSButton()
    private let nextButton = NSButton()
    private let seekBackButton = NSButton()
    private let seekForwardButton = NSButton()
    private let controlsButton = NSButton()
    private let closeButton = NSButton()

    private let brightnessSlider = NSSlider()
    private let volumeSlider = NSSlider()
    private let keyboardSlider = NSSlider()
    private let muteButton = NSButton()
    private let nativeButton = NSButton()
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

        configureButton(previousButton, symbol: "backward.fill", width: 52,
                        description: "Previous track", action: #selector(previousTapped))
        configureButton(playButton, symbol: "play.fill", width: 60,
                        description: "Play", action: #selector(playTapped))
        configureButton(nextButton, symbol: "forward.fill", width: 52,
                        description: "Next track", action: #selector(nextTapped))
        configureButton(seekBackButton, symbol: "gobackward.15", width: 52,
                        description: "Back 15 seconds", action: #selector(seekBackTapped))
        configureButton(seekForwardButton, symbol: "goforward.15", width: 52,
                        description: "Forward 15 seconds", action: #selector(seekForwardTapped))
        configureButton(controlsButton, symbol: "slider.horizontal.3",
                        description: "System controls", action: #selector(showSystemControls))
        configureButton(closeButton, symbol: "xmark.circle.fill",
                        description: "Hide Lirik", action: #selector(closeTapped))
        configureButton(muteButton, symbol: "speaker.fill",
                        description: "Mute", action: #selector(muteTapped))
        configureButton(nativeButton, symbol: "command",
                        description: "Show native Touch Bar", action: #selector(nativeTapped))
        configureButton(backButton, symbol: "music.note",
                        description: "Back to lyrics", action: #selector(showLyrics))

        configureSlider(brightnessSlider, action: #selector(brightnessChanged))
        configureSlider(volumeSlider, action: #selector(volumeChanged))
        configureSlider(keyboardSlider, action: #selector(keyboardChanged))
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
        let playImage = NSImage(
            systemSymbolName: playing ? "pause.fill" : "play.fill",
            accessibilityDescription: playing ? "Pause" : "Play"
        )
        playImage?.size = NSSize(width: 46, height: 46)
        playButton.image = playImage
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
        case Self.seekBackID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = seekBackButton
        case Self.seekForwardID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = seekForwardButton
        case Self.controlsID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = controlsButton
        case Self.closeID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = closeButton
        case Self.brightnessID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = controlView(symbol: "sun.max.fill", slider: brightnessSlider)
        case Self.volumeID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = controlView(symbol: "speaker.wave.2.fill", slider: volumeSlider)
        case Self.keyboardID:
            item = NSCustomTouchBarItem(identifier: identifier)
            item.view = controlView(symbol: "keyboard.fill", slider: keyboardSlider)
        case Self.muteID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = muteButton
        case Self.nativeID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = nativeButton
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
                Self.lyricID, .flexibleSpace,
                Self.previousID, Self.seekBackID, Self.playID,
                Self.seekForwardID, Self.nextID,
                Self.controlsID, Self.closeID
            ]
        case .controls:
            bar.defaultItemIdentifiers = [
                Self.brightnessID, Self.volumeID, Self.keyboardID, Self.muteID,
                .flexibleSpace, Self.nativeID, Self.backID
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
                                 width: CGFloat = 34,
                                 description: String, action: Selector) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        image?.size = NSSize(width: width - 10, height: width - 10)
        button.image = image
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    private func configureSlider(_ slider: NSSlider, action: Selector) {
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = 0.5
        slider.target = self
        slider.action = action
        slider.isContinuous = true
    }

    /// A slider with an SF Symbol icon on its left, so every control is labeled.
    private func controlView(symbol: String, slider: NSSlider) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 30))
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 6, width: 18, height: 18))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        slider.frame = NSRect(x: 22, y: 7, width: 124, height: 16)
        container.addSubview(imageView)
        container.addSubview(slider)
        return container
    }

    // MARK: - Actions

    @objc private func playTapped() { SpotifyService.shared.togglePlayback() }
    @objc private func previousTapped() { SpotifyService.shared.previousTrack() }
    @objc private func nextTapped() { SpotifyService.shared.nextTrack() }
    @objc private func seekBackTapped() { SpotifyService.shared.seek(by: -15) }
    @objc private func seekForwardTapped() { SpotifyService.shared.seek(by: 15) }

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
        if let keyboard = SystemControls.keyboardBrightness {
            keyboardSlider.doubleValue = Double(keyboard)
        }
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

    @objc private func keyboardChanged(_ sender: NSSlider) {
        SystemControls.keyboardBrightness = Float(sender.doubleValue)
        scheduleAutoReturn()
    }

    @objc private func muteTapped() {
        SystemControls.isMuted.toggle()
        refreshSystemControlValues()
        scheduleAutoReturn()
    }

    /// Temporarily reveals the native Touch Bar (all system functions), then
    /// brings the lyric bar back after a short delay.
    @objc private func nativeTapped() {
        autoReturnTimer?.invalidate()
        hide()
        autoReturnTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.mode = .lyrics
                self?.touchBar = self!.makeBar()
                self?.present()
            }
        }
    }
}

