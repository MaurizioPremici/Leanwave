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
    let minimizeButton = NSButton(title: "−", target: nil, action: nil)
    let closeButton = NSButton(title: "×", target: nil, action: nil)

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
    private let logoBadge = NSTextField(labelWithString: "LW")
    private let sourceCaption = NSTextField(labelWithString: "SOURCE")
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
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -22),
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

        configureWindowButton(minimizeButton, label: "Minimize window", action: #selector(minimizeWindow))
        configureWindowButton(closeButton, label: "Close window", action: #selector(closeWindow))

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

        titleLabel.font = .systemFont(ofSize: 19, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byTruncatingTail
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sourceCard.wantsLayer = true
        playerCard.wantsLayer = true
        sourceCard.layer?.cornerRadius = 18
        playerCard.layer?.cornerRadius = 18
        [sourceCard, playerCard].forEach {
            $0.layer?.borderWidth = 1
            $0.layer?.shadowOpacity = 0.18
            $0.layer?.shadowRadius = 16
            $0.layer?.shadowOffset = NSSize(width: 0, height: -5)
        }
    }

    private func makeContentStack() -> NSStackView {
        logoBadge.font = .systemFont(ofSize: 11, weight: .bold)
        logoBadge.alignment = .center
        logoBadge.wantsLayer = true
        logoBadge.layer?.cornerRadius = 10
        logoBadge.widthAnchor.constraint(equalToConstant: 38).isActive = true
        logoBadge.heightAnchor.constraint(equalToConstant: 38).isActive = true

        let brand = NSTextField(labelWithString: "Leanwave")
        brand.attributedStringValue = NSAttributedString(
            string: "LEANWAVE",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .kern: 1.8,
            ]
        )
        brand.tag = 501
        let tagline = NSTextField(labelWithString: "YouTube audio, without the visual noise.")
        tagline.font = .systemFont(ofSize: 12, weight: .regular)
        tagline.tag = 502

        let identity = NSStackView(views: [brand, tagline])
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 2
        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let windowControls = NSStackView(views: [minimizeButton, closeButton])
        windowControls.orientation = .horizontal
        windowControls.spacing = 6
        let header = NSStackView(views: [logoBadge, identity, headerSpacer, windowControls])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        sourceCaption.font = .systemFont(ofSize: 10, weight: .semibold)
        sourceCaption.tag = 503
        let inputRow = NSStackView(views: [urlField, playButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        urlField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        playButton.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let utilityRow = NSStackView(views: [pasteButton, fetchButton])
        utilityRow.orientation = .horizontal
        utilityRow.alignment = .centerY
        utilityRow.spacing = 8
        let sourceStack = NSStackView(views: [sourceCaption, inputRow, utilityRow])
        sourceStack.orientation = .vertical
        sourceStack.alignment = .leading
        sourceStack.spacing = 10
        inputRow.widthAnchor.constraint(equalTo: sourceStack.widthAnchor).isActive = true

        sourceCard.addSubview(sourceStack)
        sourceStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sourceStack.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 16),
            sourceStack.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -16),
            sourceStack.topAnchor.constraint(equalTo: sourceCard.topAnchor, constant: 15),
            sourceStack.bottomAnchor.constraint(equalTo: sourceCard.bottomAnchor, constant: -15),
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
        playerStack.spacing = 16
        playerStack.setHuggingPriority(.defaultLow, for: .horizontal)
        timeline.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true
        controls.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true

        playerCard.addSubview(playerStack)
        playerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerStack.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 18),
            playerStack.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -18),
            playerStack.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 18),
            playerStack.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -18),
        ])

        let stack = NSStackView(views: [header, sourceCard, playerCard])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sourceCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        playerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func configureTextButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.controlSize = .large
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.heightAnchor.constraint(equalToConstant: button === playButton ? 40 : 30).isActive = true
        if button !== playButton {
            button.contentTintColor = .labelColor
        }
    }

    private func configureWindowButton(_ button: NSButton, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: 18, weight: .medium)
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
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
        applyTheme(theme)
    }

    func applyTheme(_ theme: LeanwaveTheme) {
        let palette = theme.palette
        let lightTheme = theme == .arctic || theme == .paper
        view.appearance = NSAppearance(named: lightTheme ? .aqua : .darkAqua)
        view.layer?.backgroundColor = NSColor(palette.background).cgColor
        sourceCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        playerCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        sourceCard.layer?.borderColor = NSColor(palette.separator).cgColor
        playerCard.layer?.borderColor = NSColor(palette.separator).cgColor
        sourceCard.layer?.shadowColor = NSColor.black.cgColor
        playerCard.layer?.shadowColor = NSColor.black.cgColor
        logoBadge.layer?.backgroundColor = NSColor(palette.accent).withAlphaComponent(0.16).cgColor
        logoBadge.textColor = NSColor(palette.accent)
        sourceCaption.textColor = NSColor(palette.secondaryText)
        urlField.backgroundColor = NSColor(palette.background)
        urlField.textColor = NSColor(palette.primaryText)
        urlField.layer?.borderWidth = 1
        urlField.layer?.borderColor = NSColor(palette.separator).cgColor
        titleLabel.textColor = NSColor(palette.primaryText)
        statusLabel.textColor = NSColor(palette.secondaryText)
        elapsedLabel.textColor = NSColor(palette.secondaryText)
        durationLabel.textColor = NSColor(palette.secondaryText)
        seekSlider.trackFillColor = NSColor(palette.accent)
        volumeSlider.trackFillColor = NSColor(palette.accent)
        [backButton, playPauseButton, forwardButton, stopButton, muteButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
        }
        playButton.contentTintColor = lightTheme ? .white : NSColor(palette.background)
        playButton.layer?.backgroundColor = NSColor(palette.accent).cgColor
        [pasteButton, fetchButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = NSColor(palette.separator).withAlphaComponent(0.55).cgColor
        }
        [minimizeButton, closeButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = NSColor(palette.separator).withAlphaComponent(0.48).cgColor
        }
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
    @objc private func minimizeWindow() { view.window?.miniaturize(nil) }
    @objc private func closeWindow() { view.window?.performClose(nil) }

    @objc private func themeChanged() {
        let index = max(0, themePopup.indexOfSelectedItem)
        let theme = LeanwaveTheme.allCases[index]
        UserDefaults.standard.set(theme.rawValue, forKey: "leanwave.theme")
        applyTheme(theme)
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
