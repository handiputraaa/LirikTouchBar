import AppKit

/// Builds and updates the NSTouchBar shown when the Lyric Panel is frontmost.
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    private let lyricsIdentifier = NSTouchBarItem.Identifier("com.iseng.lirik.lyrics")
    private let progressIdentifier = NSTouchBarItem.Identifier("com.iseng.lirik.progress")
    private let playIdentifier = NSTouchBarItem.Identifier("com.iseng.lirik.play")

    private let lyricStack = NSStackView()
    private let lyricLabels = [
        NSTextField(labelWithString: ""),
        NSTextField(labelWithString: ""),
        NSTextField(labelWithString: "")
    ]
    private let progressBar = NSProgressIndicator()
    private let playButton = NSButton()
    private var cachedPlayingState: Bool?

    lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [lyricsIdentifier, progressIdentifier, playIdentifier]
        bar.principalItemIdentifier = lyricsIdentifier
        return bar
    }()

    private override init() {
        super.init()
        configureViews()
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case lyricsIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = lyricStack
            return item

        case progressIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = progressBar
            return item

        case playIdentifier:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = playButton
            return item

        default:
            return nil
        }
    }

    // MARK: - Updates

    @MainActor
    func update() {
        let state = LyricsController.shared
        let settings = AppSettings.shared
        let texts = [state.currentLine, state.upcomingLine, state.secondUpcomingLine]

        for (index, label) in lyricLabels.enumerated() {
            let visible = index < settings.lineCount && !texts[index].isEmpty
            label.isHidden = !visible
            if visible {
                let size = index == 0 ? settings.fontSize : max(settings.fontSize - 4, 9)
                label.font = NSFont.systemFont(
                    ofSize: CGFloat(size),
                    weight: index == 0 ? .semibold : .regular
                )
                label.textColor = index == 0 ? .labelColor : .secondaryLabelColor
                label.stringValue = index == 0 ? texts[index] : "next  \(texts[index])"
            }
        }

        progressBar.doubleValue = state.progress

        if cachedPlayingState != state.isPlaying {
            cachedPlayingState = state.isPlaying
            let symbol = state.isPlaying ? "pause.fill" : "play.fill"
            playButton.image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: state.isPlaying ? "Pause" : "Play"
            )
        }
    }

    // MARK: - Private

    private func configureViews() {
        lyricStack.orientation = .vertical
        lyricStack.alignment = .leading
        lyricStack.spacing = 1

        for label in lyricLabels {
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            lyricStack.addArrangedSubview(label)
        }
        lyricStack.translatesAutoresizingMaskIntoConstraints = false
        lyricStack.widthAnchor.constraint(equalToConstant: 380).isActive = true

        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.widthAnchor.constraint(equalToConstant: 150).isActive = true

        playButton.bezelStyle = .rounded
        playButton.imagePosition = .imageOnly
        playButton.target = self
        playButton.action = #selector(togglePlayback)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
    }

    @objc private func togglePlayback() {
        SpotifyService.shared.togglePlayback()
    }
}
