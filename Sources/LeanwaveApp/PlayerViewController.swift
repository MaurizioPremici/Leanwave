import AppKit
import LeanwaveCore

@MainActor
final class PlayerViewController: NSViewController, NSTextFieldDelegate, @unchecked Sendable {
    let urlField = NSTextField(string: "")
    let linkButton = NSButton(title: "Link", target: nil, action: nil)
    let youtubeButton = NSButton()
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

    var sourceCardIsHidden: Bool { sourceCard.isHidden }

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
    private let logoBadge = NSImageView()
    private let sourceCaption = NSTextField(labelWithString: "SOURCE")
    private let pulseRing = NSView()
    private let loadingIndicator = NSProgressIndicator()
    private let audioIndicator = NSImageView()
    private let chromeChoiceBar = NSView()
    private let closeTabChoiceButton = NSButton(title: "Close Tab", target: nil, action: nil)
    private let quitChromeChoiceButton = NSButton(title: "Quit", target: nil, action: nil)
    private let keepOpenChoiceButton = NSButton(title: "Keep", target: nil, action: nil)
    private weak var nowPlayingStack: NSStackView?
    private var currentTheme: LeanwaveTheme = .aqua
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
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -10),
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

        configureTextButton(linkButton, action: #selector(toggleSourcePanel))
        configureSymbolButton(youtubeButton, symbol: "play.rectangle.fill", fallback: "YT", label: "Open YouTube in Chrome", action: #selector(openYouTube))
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
        themePopup.setAccessibilityLabel("Accent color")
        themePopup.controlSize = .small

        configureChoiceButton(closeTabChoiceButton, action: #selector(closeYouTubeTab))
        configureChoiceButton(quitChromeChoiceButton, action: #selector(quitChrome))
        configureChoiceButton(keepOpenChoiceButton, action: #selector(keepChromeOpen))

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false
        loadingIndicator.widthAnchor.constraint(equalToConstant: 14).isActive = true
        loadingIndicator.heightAnchor.constraint(equalToConstant: 14).isActive = true
        audioIndicator.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Audio is playing")
        audioIndicator.imageScaling = .scaleProportionallyDown
        audioIndicator.isHidden = true
        audioIndicator.widthAnchor.constraint(equalToConstant: 17).isActive = true
        audioIndicator.heightAnchor.constraint(equalToConstant: 14).isActive = true

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 9)
        statusLabel.lineBreakMode = .byTruncatingTail
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sourceCard.wantsLayer = true
        playerCard.wantsLayer = true
        pulseRing.wantsLayer = true
        chromeChoiceBar.wantsLayer = true
        sourceCard.layer?.cornerRadius = 13
        playerCard.layer?.cornerRadius = 16
        chromeChoiceBar.layer?.cornerRadius = 10
        chromeChoiceBar.layer?.borderWidth = 1
        [sourceCard, playerCard].forEach {
            $0.layer?.borderWidth = 1
            $0.layer?.shadowOpacity = 0.18
            $0.layer?.shadowRadius = 16
            $0.layer?.shadowOffset = NSSize(width: 0, height: -5)
        }
        sourceCard.isHidden = true
        chromeChoiceBar.isHidden = true
    }

    private func makeContentStack() -> NSStackView {
        logoBadge.image = NSApp.applicationIconImage
        logoBadge.imageScaling = .scaleProportionallyUpOrDown
        logoBadge.wantsLayer = true
        logoBadge.layer?.cornerRadius = 11
        logoBadge.layer?.masksToBounds = true
        logoBadge.widthAnchor.constraint(equalToConstant: 36).isActive = true
        logoBadge.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let brand = NSTextField(labelWithString: "Leanwave")
        brand.attributedStringValue = NSAttributedString(
            string: "LEANWAVE",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .kern: 2.0,
            ]
        )
        brand.tag = 501
        let tagline = NSTextField(labelWithString: "YouTube audio, without the visual noise.")
        tagline.font = .systemFont(ofSize: 9, weight: .medium)
        tagline.tag = 502
        let identity = NSStackView(views: [brand, tagline])
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 2
        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let windowControls = NSStackView(views: [minimizeButton, closeButton])
        windowControls.orientation = .horizontal
        windowControls.spacing = 5
        let header = NSStackView(views: [logoBadge, identity, linkButton, youtubeButton, themePopup, headerSpacer, windowControls])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        sourceCaption.font = .systemFont(ofSize: 10, weight: .semibold)
        sourceCaption.tag = 503
        let inputRow = NSStackView(views: [urlField, playButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        urlField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        playButton.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let utilityRow = NSStackView(views: [pasteButton, fetchButton])
        utilityRow.orientation = .horizontal
        utilityRow.alignment = .centerY
        utilityRow.spacing = 8
        let sourceStack = NSStackView(views: [sourceCaption, inputRow, utilityRow])
        sourceStack.orientation = .vertical
        sourceStack.alignment = .leading
        sourceStack.spacing = 8
        inputRow.widthAnchor.constraint(equalTo: sourceStack.widthAnchor).isActive = true

        sourceCard.addSubview(sourceStack)
        sourceStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sourceStack.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 13),
            sourceStack.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -13),
            sourceStack.topAnchor.constraint(equalTo: sourceCard.topAnchor, constant: 8),
            sourceStack.bottomAnchor.constraint(equalTo: sourceCard.bottomAnchor, constant: -8),
        ])

        let statusRow = NSStackView(views: [loadingIndicator, audioIndicator, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 5
        let titleStack = NSStackView(views: [titleLabel, statusRow])
        titleStack.orientation = .vertical
        titleStack.alignment = .centerX
        titleStack.spacing = 3
        nowPlayingStack = titleStack

        let chromePrompt = NSTextField(labelWithString: "Chrome")
        chromePrompt.font = .systemFont(ofSize: 10, weight: .semibold)
        chromePrompt.tag = 505
        let chromeActions = NSStackView(views: [closeTabChoiceButton, quitChromeChoiceButton, keepOpenChoiceButton])
        chromeActions.orientation = .horizontal
        chromeActions.alignment = .centerY
        chromeActions.spacing = 6
        let chromeRow = NSStackView(views: [chromePrompt, chromeActions])
        chromeRow.orientation = .horizontal
        chromeRow.alignment = .centerY
        chromeRow.spacing = 9
        chromeChoiceBar.addSubview(chromeRow)
        chromeRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chromeRow.centerXAnchor.constraint(equalTo: chromeChoiceBar.centerXAnchor),
            chromeRow.centerYAnchor.constraint(equalTo: chromeChoiceBar.centerYAnchor),
            chromeChoiceBar.heightAnchor.constraint(equalToConstant: 30),
        ])

        let timeline = NSStackView(views: [elapsedLabel, seekSlider, durationLabel])
        timeline.orientation = .horizontal
        timeline.alignment = .centerY
        timeline.spacing = 10
        elapsedLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true
        durationLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let playContainer = NSView()
        playContainer.addSubview(pulseRing)
        playContainer.addSubview(playPauseButton)
        pulseRing.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        pulseRing.layer?.cornerRadius = 19
        pulseRing.layer?.borderWidth = 1.5
        NSLayoutConstraint.activate([
            playContainer.widthAnchor.constraint(equalToConstant: 42),
            playContainer.heightAnchor.constraint(equalToConstant: 42),
            pulseRing.centerXAnchor.constraint(equalTo: playContainer.centerXAnchor),
            pulseRing.centerYAnchor.constraint(equalTo: playContainer.centerYAnchor),
            pulseRing.widthAnchor.constraint(equalToConstant: 38),
            pulseRing.heightAnchor.constraint(equalToConstant: 38),
            playPauseButton.centerXAnchor.constraint(equalTo: playContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: playContainer.centerYAnchor),
        ])

        let transport = NSStackView(views: [backButton, playContainer, forwardButton])
        transport.orientation = .horizontal
        transport.alignment = .centerY
        transport.spacing = 16

        let volume = NSStackView(views: [muteButton, volumeSlider])
        volume.orientation = .horizontal
        volume.alignment = .centerY
        volume.spacing = 6
        volumeSlider.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let controlSpacer = NSView()
        controlSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let controls = NSStackView(views: [transport, stopButton, controlSpacer, volume])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 10

        let playerStack = NSStackView(views: [titleStack, chromeChoiceBar, controls, timeline])
        playerStack.orientation = .vertical
        playerStack.alignment = .centerX
        playerStack.spacing = 4
        playerStack.setHuggingPriority(.defaultLow, for: .horizontal)
        timeline.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true
        titleStack.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true
        chromeChoiceBar.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true
        controls.widthAnchor.constraint(equalTo: playerStack.widthAnchor).isActive = true

        playerCard.addSubview(playerStack)
        playerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerStack.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 16),
            playerStack.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -16),
            playerStack.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 6),
            playerStack.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -6),
        ])

        let stack = NSStackView(views: [header, sourceCard, playerCard])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sourceCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        playerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func configureTextButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.heightAnchor.constraint(equalToConstant: button === playButton ? 40 : 28).isActive = true
        if button === linkButton { button.widthAnchor.constraint(equalToConstant: 48).isActive = true }
        if button !== playButton {
            button.contentTintColor = .labelColor
        }
    }

    private func configureWindowButton(_ button: NSButton, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: 16, weight: .medium)
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.widthAnchor.constraint(equalToConstant: 27).isActive = true
        button.heightAnchor.constraint(equalToConstant: 27).isActive = true
    }

    private func configureChoiceButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: 10, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
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
        button.isBordered = false
        button.wantsLayer = true
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label) {
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = fallback
        }
        button.setAccessibilityLabel(label)
        button.toolTip = label
        let size: CGFloat = button === playPauseButton ? 34 : 30
        button.layer?.cornerRadius = size / 2
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    private func applyStoredTheme() {
        let stored = UserDefaults.standard.string(forKey: "leanwave.theme") ?? LeanwaveTheme.aqua.rawValue
        let theme = LeanwaveTheme(rawValue: stored) ?? .aqua
        themePopup.selectItem(at: LeanwaveTheme.allCases.firstIndex(of: theme) ?? 0)
        applyTheme(theme)
    }

    func applyTheme(_ theme: LeanwaveTheme) {
        currentTheme = theme
        let palette = theme.palette
        let accent = NSColor(palette.accent)
        let separator = NSColor(palette.separator)
        view.appearance = NSAppearance(named: .darkAqua)
        view.layer?.backgroundColor = NSColor(palette.background).cgColor
        sourceCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        playerCard.layer?.backgroundColor = NSColor(palette.surface).cgColor
        sourceCard.layer?.borderColor = NSColor(palette.separator).cgColor
        playerCard.layer?.borderColor = NSColor(palette.separator).cgColor
        chromeChoiceBar.layer?.backgroundColor = separator.withAlphaComponent(0.25).cgColor
        chromeChoiceBar.layer?.borderColor = accent.withAlphaComponent(0.38).cgColor
        sourceCard.layer?.shadowColor = NSColor.black.cgColor
        playerCard.layer?.shadowColor = NSColor.black.cgColor
        pulseRing.layer?.borderColor = accent.withAlphaComponent(0.62).cgColor
        sourceCaption.textColor = NSColor(palette.secondaryText)
        urlField.backgroundColor = NSColor(palette.background)
        urlField.textColor = NSColor(palette.primaryText)
        urlField.layer?.borderWidth = 1
        urlField.layer?.borderColor = NSColor(palette.separator).cgColor
        titleLabel.textColor = NSColor(palette.primaryText)
        statusLabel.textColor = NSColor(palette.secondaryText)
        elapsedLabel.textColor = NSColor(palette.secondaryText)
        durationLabel.textColor = NSColor(palette.secondaryText)
        audioIndicator.contentTintColor = accent
        seekSlider.trackFillColor = accent
        volumeSlider.trackFillColor = accent
        [backButton, forwardButton, stopButton, muteButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = separator.withAlphaComponent(0.45).cgColor
        }
        playPauseButton.contentTintColor = NSColor(palette.background)
        playPauseButton.layer?.backgroundColor = accent.cgColor
        playButton.contentTintColor = NSColor(palette.background)
        playButton.layer?.backgroundColor = accent.cgColor
        [linkButton, youtubeButton, pasteButton, fetchButton, closeTabChoiceButton, quitChromeChoiceButton, keepOpenChoiceButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = separator.withAlphaComponent(0.48).cgColor
        }
        [minimizeButton, closeButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = NSColor(palette.separator).withAlphaComponent(0.48).cgColor
        }
        view.viewWithTag(501).flatMap { $0 as? NSTextField }?.textColor = accent
        view.viewWithTag(502).flatMap { $0 as? NSTextField }?.textColor = NSColor(palette.primaryText)
        view.viewWithTag(505).flatMap { $0 as? NSTextField }?.textColor = accent
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
        let showsPlay = state.phase != .playing || state.isPaused
        updateSymbol(playPauseButton, symbol: showsPlay ? "play.fill" : "pause.fill", fallback: showsPlay ? "Play" : "Pause")
        updateSymbol(muteButton, symbol: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", fallback: state.isMuted ? "Unmute" : "Mute")

        switch state.phase {
        case .idle:
            statusLabel.stringValue = "Ready for a YouTube URL."
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = true
        case .loading:
            statusLabel.stringValue = "Connecting to the audio stream…"
            loadingIndicator.startAnimation(nil)
            audioIndicator.isHidden = true
        case .playing: statusLabel.stringValue = state.isPaused ? "Paused" : "Playing audio only"
        case .failed(let message):
            statusLabel.stringValue = message
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = true
        }

        if state.phase == .playing {
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = state.isPaused
        }

        setPulseActive(state.phase == .playing && !state.isPaused)

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

    private func setPulseActive(_ active: Bool) {
        pulseRing.layer?.removeAnimation(forKey: "leanwave.pulse")
        guard active else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.92
        animation.toValue = 1.08
        animation.duration = 1.15
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseRing.layer?.add(animation, forKey: "leanwave.pulse")
    }

    private func presentChromeChoice() {
        player.markCloseChoiceHandled()
        nowPlayingStack?.isHidden = true
        chromeChoiceBar.isHidden = false
    }

    private func dismissChromeChoice(message: String) {
        chromeChoiceBar.isHidden = true
        nowPlayingStack?.isHidden = false
        statusLabel.stringValue = message
    }

    private func closePlayingTab() {
        do {
            guard let url = playingURL else { return }
            let reference: ChromeTabReference?
            if let fetchedReference, fetchedReference.url.normalizedString == url.normalizedString {
                reference = fetchedReference
            } else {
                reference = try chrome.findTab(matching: url)
            }
            guard let reference else { throw ChromeControllerError.tabChanged }
            try chrome.closeTab(reference)
            dismissChromeChoice(message: "The YouTube tab was closed.")
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
        sourceCard.isHidden = true
        playerCard.isHidden = false
        linkButton.contentTintColor = NSColor(currentTheme.palette.primaryText)
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

    @objc private func toggleSourcePanel() {
        let opening = sourceCard.isHidden
        sourceCard.isHidden = !opening
        playerCard.isHidden = opening
        linkButton.contentTintColor = sourceCard.isHidden
            ? NSColor(currentTheme.palette.primaryText)
            : NSColor(currentTheme.palette.accent)
    }

    @objc private func openYouTube() {
        do {
            try chrome.openYouTube()
            statusLabel.stringValue = "YouTube opened in Google Chrome."
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func closeYouTubeTab() { closePlayingTab() }
    @objc private func quitChrome() {
        do {
            try chrome.quitChrome()
            dismissChromeChoice(message: "Google Chrome was closed.")
        } catch {
            showError(error.localizedDescription)
        }
    }
    @objc private func keepChromeOpen() { dismissChromeChoice(message: "Google Chrome stays open.") }

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
