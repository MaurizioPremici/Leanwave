import AppKit
import LeanwaveCore

@MainActor
final class PlayerViewController: NSViewController, NSTextFieldDelegate, @unchecked Sendable {
    let urlField = NSTextField(string: "")
    let pasteButton = NSButton(title: "Paste", target: nil, action: nil)
    let fetchButton = NSButton(title: "Fetch Again", target: nil, action: nil)
    let playButton = NSButton(title: "Play", target: nil, action: nil)
    let backButton = NSButton()
    let playPauseButton = NSButton()
    let forwardButton = NSButton()
    let stopButton = NSButton()
    let muteButton = NSButton()
    let themePopup = NSPopUpButton()

    private let player: PlayerController
    private let chrome: ChromeController
    private let titleLabel = NSTextField(labelWithString: "Ready")
    private let statusLabel = NSTextField(labelWithString: "Open a YouTube page or paste its URL.")
    private let elapsedLabel = NSTextField(labelWithString: "0:00")
    private let durationLabel = NSTextField(labelWithString: "0:00")
    private let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let volumeSlider = NSSlider(value: 75, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let sourceCard = NSView()
    private let playerCard = NSView()
    private var fetchedReference: ChromeTabReference?
    private var playingURL: YouTubeURL?
    private var lastState = PlayerState()

    init(player: PlayerController = PlayerController(), chrome: ChromeController = ChromeController()) {
        self.player = player
        self.chrome = chrome
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        view = root

        configureControls()
        let content = makeContentStack()
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 26),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -24),
        ])

        player.onStateChange = { [weak self] state in
            Task { @MainActor in self?.render(state) }
        }
        applyStoredTheme()
        render(player.state)
    }

    func fetchFromChrome(showErrors: Bool) {
        do {
            let reference = try chrome.fetchActiveTab()
            fetchedReference = reference
            urlField.stringValue = reference.url.normalizedString
            statusLabel.stringValue = "Fetched the active YouTube tab."
        } catch {
            fetchedReference = nil
            if showErrors {
                showError(error.localizedDescription)
            } else {
                statusLabel.stringValue = "Paste a YouTube URL or open one in Chrome."
            }
        }
    }

    func stopPlayback() {
        player.stop()
    }

    private func configureControls() {
        urlField.placeholderString = "Paste a YouTube URL"
        urlField.font = .systemFont(ofSize: 13)
        urlField.isBezeled = false
        urlField.drawsBackground = true
        urlField.focusRingType = .none
        urlField.delegate = self
        urlField.wantsLayer = true
        urlField.layer?.cornerRadius = 9
        urlField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        configureTextButton(pasteButton, action: #selector(pasteURL))
        configureTextButton(fetchButton, action: #selector(fetchAgain))
        configureTextButton(playButton, action: #selector(playURL))
        playButton.keyEquivalent = "\r"

        configureSymbolButton(backButton, symbol: "gobackward.15", fallback: "−15", label: "Back 15 seconds", action: #selector(seekBackward))
        configureSymbolButton(playPauseButton, symbol: "play.fill", fallback: "Play", label: "Play or pause", action: #selector(togglePause))
        configureSymbolButton(forwardButton, symbol: "goforward.15", fallback: "+15", label: "Forward 15 seconds", action: #selector(seekForward))
        configureSymbolButton(stopButton, symbol: "stop.fill", fallback: "Stop", label: "Stop", action: #selector(stopPressed))
        configureSymbolButton(muteButton, symbol: "speaker.wave.2.fill", fallback: "Mute", label: "Mute or unmute", action: #selector(toggleMute))
        playPauseButton.keyEquivalent = " "

        seekSlider.target = self
        seekSlider.action = #selector(seekChanged)
        seekSlider.isContinuous = false
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        volumeSlider.isContinuous = true
        volumeSlider.setAccessibilityLabel("Volume")

        themePopup.addItems(withTitles: LeanwaveTheme.allCases.map(\.displayName))
        themePopup.target = self
        themePopup.action = #selector(themeChanged)
        themePopup.setAccessibilityLabel("Theme")

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byTruncatingTail
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sourceCard.wantsLayer = true
        playerCard.wantsLayer = true
        sourceCard.layer?.cornerRadius = 14
        playerCard.layer?.cornerRadius = 14
    }

    private func makeContentStack() -> NSStackView {
        let brand = NSTextField(labelWithString: "LEANWAVE")
        brand.attributedStringValue = NSAttributedString(
            string: "LEANWAVE",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .kern: 2.2,
            ]
        )
        brand.tag = 501
        let tagline = NSTextField(labelWithString: "YouTube audio, minus the browser.")
        tagline.font = .systemFont(ofSize: 24, weight: .semibold)
        tagline.tag = 502

        let inputRow = NSStackView(views: [urlField, pasteButton, fetchButton, playButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        urlField.heightAnchor.constraint(equalToConstant: 38).isActive = true
        playButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

        sourceCard.addSubview(inputRow)
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inputRow.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 14),
            inputRow.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -14),
            inputRow.topAnchor.constraint(equalTo: sourceCard.topAnchor, constant: 14),
            inputRow.bottomAnchor.constraint(equalTo: sourceCard.bottomAnchor, constant: -14),
        ])

        let titleStack = NSStackView(views: [titleLabel, statusLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        let timeline = NSStackView(views: [elapsedLabel, seekSlider, durationLabel])
        timeline.orientation = .horizontal
        timeline.alignment = .centerY
        timeline.spacing = 10
        elapsedLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true
        durationLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let transport = NSStackView(views: [backButton, playPauseButton, forwardButton, stopButton])
        transport.orientation = .horizontal
        transport.alignment = .centerY
        transport.spacing = 10

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let volume = NSStackView(views: [muteButton, volumeSlider])
        volume.orientation = .horizontal
        volume.alignment = .centerY
        volume.spacing = 8
        volumeSlider.widthAnchor.constraint(equalToConstant: 112).isActive = true

        let controls = NSStackView(views: [transport, spacer, volume, themePopup])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12

        let playerStack = NSStackView(views: [titleStack, timeline, controls])
        playerStack.orientation = .vertical
        playerStack.alignment = .leading
        playerStack.spacing = 18
        playerStack.setHuggingPriority(.defaultLow, for: .horizontal)
        timeline.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true
        controls.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true

        playerCard.addSubview(playerStack)
        playerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerStack.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 20),
            playerStack.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -20),
            playerStack.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 20),
            playerStack.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -20),
        ])

        let stack = NSStackView(views: [brand, tagline, sourceCard, playerCard])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        sourceCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        playerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func configureTextButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 12, weight: .medium)
    }

    private func configureSymbolButton(
        _ button: NSButton,
        symbol: String,
        fallback: String,
        label: String,
        action: Selector
    ) {
        button.target = self
        button.action = action
        button.bezelStyle = .texturedRounded
        button.controlSize = .large
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label) {
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = fallback
        }
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    private func applyStoredTheme() {
        let stored = UserDefaults.standard.string(forKey: "leanwave.theme") ?? LeanwaveTheme.carbon.rawValue
        let theme = LeanwaveTheme(rawValue: stored) ?? .carbon
        themePopup.selectItem(at: LeanwaveTheme.allCases.firstIndex(of: theme) ?? 0)
        apply(theme)
    }

    private func apply(_ theme: LeanwaveTheme) {
        let palette = theme.palette
        view.layer?.backgroundColor = NSColor(palette.background).cgColor
        sourceCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        playerCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        urlField.backgroundColor = NSColor(palette.background)
        urlField.textColor = NSColor(palette.primaryText)
        titleLabel.textColor = NSColor(palette.primaryText)
        statusLabel.textColor = NSColor(palette.secondaryText)
        elapsedLabel.textColor = NSColor(palette.secondaryText)
        durationLabel.textColor = NSColor(palette.secondaryText)
        seekSlider.trackFillColor = NSColor(palette.accent)
        volumeSlider.trackFillColor = NSColor(palette.accent)
        [backButton, playPauseButton, forwardButton, stopButton, muteButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
        }
        playButton.contentTintColor = NSColor(palette.accent)
        view.viewWithTag(501).flatMap { $0 as? NSTextField }?.textColor = NSColor(palette.accent)
        view.viewWithTag(502).flatMap { $0 as? NSTextField }?.textColor = NSColor(palette.primaryText)
    }

    private func render(_ state: PlayerState) {
        lastState = state
        titleLabel.stringValue = state.title
        elapsedLabel.stringValue = TimeText.format(state.position)
        durationLabel.stringValue = TimeText.format(state.duration ?? 0)
        seekSlider.maxValue = max(1, state.duration ?? 1)
        if !seekSlider.isHighlighted { seekSlider.doubleValue = min(state.position, seekSlider.maxValue) }
        volumeSlider.doubleValue = state.volume
        let active = state.phase == .playing || state.phase == .loading
        [backButton, playPauseButton, forwardButton, stopButton, muteButton, seekSlider, volumeSlider].forEach {
            $0.isEnabled = active
        }
        updateSymbol(playPauseButton, symbol: state.isPaused ? "play.fill" : "pause.fill", fallback: state.isPaused ? "Play" : "Pause")
        updateSymbol(muteButton, symbol: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", fallback: state.isMuted ? "Unmute" : "Mute")

        switch state.phase {
        case .idle: statusLabel.stringValue = "Ready for a YouTube URL."
        case .loading: statusLabel.stringValue = "Connecting to the audio stream…"
        case .playing: statusLabel.stringValue = state.isPaused ? "Paused" : "Playing audio only"
        case .failed(let message): statusLabel.stringValue = message
        }

        if state.closeChoicePending { presentChromeChoice() }
    }

    private func updateSymbol(_ button: NSButton, symbol: String, fallback: String) {
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: button.accessibilityLabel()) {
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
        } else {
            button.image = nil
            button.title = fallback
        }
    }

    private func presentChromeChoice() {
        player.markCloseChoiceHandled()
        let alert = NSAlert()
        alert.messageText = "Audio is playing"
        alert.informativeText = "What should Leanwave do with Google Chrome?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Close YouTube Tab")
        alert.addButton(withTitle: "Quit Chrome")
        alert.addButton(withTitle: "Keep Open")
        let response = alert.runModal()
        do {
            if response == .alertFirstButtonReturn {
                guard let url = playingURL else { return }
                let reference: ChromeTabReference?
                if let fetchedReference, fetchedReference.url.normalizedString == url.normalizedString {
                    reference = fetchedReference
                } else {
                    reference = try chrome.findTab(matching: url)
                }
                guard let reference else { throw ChromeControllerError.tabChanged }
                try chrome.closeTab(reference)
                statusLabel.stringValue = "The YouTube tab was closed."
            } else if response == .alertSecondButtonReturn {
                try chrome.quitChrome()
                statusLabel.stringValue = "Google Chrome was closed."
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        statusLabel.stringValue = message
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Leanwave"
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func pasteURL() {
        guard let text = NSPasteboard.general.string(forType: .string)?.split(whereSeparator: \.isNewline).first else {
            showError("The clipboard does not contain a URL.")
            return
        }
        urlField.stringValue = String(text)
        fetchedReference = nil
    }

    @objc private func fetchAgain() {
        fetchFromChrome(showErrors: true)
    }

    @objc private func playURL() {
        guard let url = YouTubeURL(urlField.stringValue) else {
            showError("Enter a valid YouTube URL.")
            return
        }
        playingURL = url
        if fetchedReference?.url.normalizedString != url.normalizedString { fetchedReference = nil }
        do {
            try player.play(url: url)
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func togglePause() { player.togglePause() }
    @objc private func seekBackward() { player.seek(seconds: -15) }
    @objc private func seekForward() { player.seek(seconds: 15) }
    @objc private func stopPressed() { player.stop() }
    @objc private func toggleMute() { player.toggleMute() }
    @objc private func seekChanged() { player.seek(to: seekSlider.doubleValue) }
    @objc private func volumeChanged() { player.setVolume(volumeSlider.doubleValue) }

    @objc private func themeChanged() {
        let index = max(0, themePopup.indexOfSelectedItem)
        let theme = LeanwaveTheme.allCases[index]
        UserDefaults.standard.set(theme.rawValue, forKey: "leanwave.theme")
        apply(theme)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let fetchedReference else { return }
        if YouTubeURL(urlField.stringValue)?.normalizedString != fetchedReference.url.normalizedString {
            self.fetchedReference = nil
        }
    }
}

private extension NSColor {
    convenience init(_ color: RGBAColor) {
        self.init(
            calibratedRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }
}
