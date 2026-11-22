import AppKit

/// The always-visible, system-modal lyric bar on the physical Touch Bar.
/// Two modes: lyrics (with transport controls) and system controls
/// (brightness / volume), since the full-width presentation hides Control Strip.
final class SystemLyricsTouchBar: NSObject, NSTouchBarDelegate {
    static let shared = SystemLyricsTouchBar()

    private enum Mode { case lyrics, controls, functionKeys }

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
    private static let brightnessDownID = NSTouchBarItem.Identifier("com.iseng.lirik.brightness.down")
    private static let brightnessUpID = NSTouchBarItem.Identifier("com.iseng.lirik.brightness.up")
    private static let volumeDownID = NSTouchBarItem.Identifier("com.iseng.lirik.volume.down")
    private static let volumeUpID = NSTouchBarItem.Identifier("com.iseng.lirik.volume.up")
    private static let keyboardDownID = NSTouchBarItem.Identifier("com.iseng.lirik.keyboard.down")
    private static let keyboardUpID = NSTouchBarItem.Identifier("com.iseng.lirik.keyboard.up")
    private static let launchpadID = NSTouchBarItem.Identifier("com.iseng.lirik.launchpad")

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

    private let brightnessDownButton = NSButton()
    private let brightnessUpButton = NSButton()
    private let volumeDownButton = NSButton()
    private let volumeUpButton = NSButton()
    private let keyboardDownButton = NSButton()
    private let keyboardUpButton = NSButton()
    private let launchpadButton = NSButton()

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

        configureButton(brightnessDownButton, symbol: "sun.min.fill", width: 60,
                        description: "Decrease brightness", action: #selector(brightnessDown))
        configureButton(brightnessUpButton, symbol: "sun.max.fill", width: 60,
                        description: "Increase brightness", action: #selector(brightnessUp))
        configureButton(volumeDownButton, symbol: "speaker.wave.1.fill", width: 60,
                        description: "Decrease volume", action: #selector(volumeDown))
        configureButton(volumeUpButton, symbol: "speaker.wave.3.fill", width: 60,
                        description: "Increase volume", action: #selector(volumeUp))
        configureButton(keyboardDownButton, symbol: "keyboard", width: 70,
                        description: "Decrease keyboard light", action: #selector(keyboardDown))
        let keyboardDim = KeyboardLightIcon.image(increase: false)
        keyboardDim.size = NSSize(width: 40, height: 40)
        keyboardDownButton.image = keyboardDim
        keyboardDownButton.imageScaling = .scaleProportionallyUpOrDown
        configureButton(keyboardUpButton, symbol: "keyboard.fill", width: 70,
                        description: "Increase keyboard light", action: #selector(keyboardUp))
        let keyboardBright = KeyboardLightIcon.image(increase: true)
        keyboardBright.size = NSSize(width: 40, height: 40)
        keyboardUpButton.image = keyboardBright
        configureButton(launchpadButton, symbol: "square.grid.2x2.fill", width: 52,
                        description: "Launchpad", action: #selector(launchpadTapped))
        keyboardUpButton.imageScaling = .scaleProportionallyUpOrDown

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
            item.view = controlView(symbol: nil, slider: keyboardSlider,
                                    image: KeyboardLightIcon.image(increase: true))
        case Self.muteID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = muteButton
        case Self.nativeID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = nativeButton
        case Self.backID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = backButton
        case Self.brightnessDownID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = brightnessDownButton
        case Self.brightnessUpID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = brightnessUpButton
        case Self.volumeDownID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = volumeDownButton
        case Self.volumeUpID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = volumeUpButton
        case Self.keyboardDownID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = keyboardDownButton
        case Self.keyboardUpID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = keyboardUpButton
        case Self.launchpadID:
            item = NSCustomTouchBarItem(identifier: identifier); item.view = launchpadButton
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
        case .functionKeys:
            bar.defaultItemIdentifiers = [
                Self.brightnessDownID, Self.brightnessUpID,
                Self.volumeDownID, Self.volumeUpID,
                Self.keyboardDownID, Self.keyboardUpID, Self.launchpadID
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
    private func controlView(symbol: String?, slider: NSSlider,
                             image: NSImage? = nil) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 30))
        let resolvedImage = image ?? NSImage(systemSymbolName: symbol ?? "",
                                             accessibilityDescription: nil)
        let imageView = NSImageView(frame: NSRect(x: 0, y: 6, width: 18, height: 18))
        imageView.image = resolvedImage
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

    /// Called when the Fn / Globe key is pressed while the lyric bar is active.
    func showFunctionKeys() {
        guard isPresented else { return }
        mode = .functionKeys
        touchBar = makeBar()
        present()
        // Fn is a hold-style key on macOS; return to lyrics shortly after.
        autoReturnTimer?.invalidate()
        autoReturnTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.showLyrics() }
        }
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

    // MARK: Fn-key step controls

    private func step(_ current: Float?, by delta: Float,
                      apply: (Float) -> Void) {
        let base = current ?? 0.5
        apply(min(1, max(0, base + delta)))
        refreshSystemControlValues()
        // Keep the Fn row visible while the user is tapping it.
        if mode == .functionKeys { showFunctionKeys() }
    }

    @objc private func brightnessDown() {
        step(SystemControls.brightness, by: -0.0625) { SystemControls.brightness = $0 }
    }

    @objc private func brightnessUp() {
        step(SystemControls.brightness, by: 0.0625) { SystemControls.brightness = $0 }
    }

    @objc private func volumeDown() {
        step(SystemControls.volume, by: -0.0625) { SystemControls.volume = $0 }
    }

    @objc private func volumeUp() {
        step(SystemControls.volume, by: 0.0625) {
            SystemControls.volume = $0
            if $0 > 0, SystemControls.isMuted { SystemControls.isMuted = false }
        }
    }

    @objc private func keyboardDown() {
        step(SystemControls.keyboardBrightness, by: -0.125) { SystemControls.keyboardBrightness = $0 }
    }

    @objc private func keyboardUp() {
        step(SystemControls.keyboardBrightness, by: 0.125) { SystemControls.keyboardBrightness = $0 }
    }

    @objc private func launchpadTapped() {
        let url = URL(fileURLWithPath: "/System/Applications/Launchpad.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        showLyrics()
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

