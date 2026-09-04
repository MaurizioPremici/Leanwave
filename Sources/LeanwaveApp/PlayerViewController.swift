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
    private let titleLabel = NSTextField(labelWithString: "Ready to play")
    private let statusLabel = NSTextField(labelWithString: "Open a YouTube video to load audio.")
    private let elapsedLabel = NSTextField(labelWithString: "0:00")
    private let durationLabel = NSTextField(labelWithString: "0:00")
    private let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let volumeSlider = NSSlider(value: 75, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let sourceCard = AuroraCardView()
    private let playerCard = AuroraCardView()
    private let logoBadge = NSImageView()
    private let sourceCaption = NSTextField(labelWithString: "SOURCE")
    private let pulseRing = NSView()
    private let loadingIndicator = NSProgressIndicator()
    private let audioIndicator = NSImageView()
    private let audioIndicatorRight = NSImageView()
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
        let root = AuroraBackgroundView()
        root.wantsLayer = true
        view = root

        configureControls()
        let content = makeContentStack()
        root.addSubview(content)
        root.addSubview(linkButton)
        linkButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            linkButton.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            linkButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -46),
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
        linkButton.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Show link controls")
        linkButton.imagePosition = .imageLeading
        linkButton.imageHugsTitle = true
        linkButton.setAccessibilityLabel("Show link controls")
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
        themePopup.controlSize = .regular
        themePopup.widthAnchor.constraint(equalToConstant: 156).isActive = true
        themePopup.heightAnchor.constraint(equalToConstant: 36).isActive = true

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
        audioIndicator.wantsLayer = true
        audioIndicator.widthAnchor.constraint(equalToConstant: 18).isActive = true
        audioIndicator.heightAnchor.constraint(equalToConstant: 14).isActive = true
        audioIndicatorRight.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        audioIndicatorRight.imageScaling = .scaleProportionallyDown
        audioIndicatorRight.wantsLayer = true
        audioIndicatorRight.widthAnchor.constraint(equalToConstant: 18).isActive = true
        audioIndicatorRight.heightAnchor.constraint(equalToConstant: 14).isActive = true

        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingTail
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        sourceCard.wantsLayer = true
        playerCard.wantsLayer = true
        pulseRing.wantsLayer = true
        chromeChoiceBar.wantsLayer = true
        sourceCard.layer?.cornerRadius = 22
        playerCard.layer?.cornerRadius = 22
        chromeChoiceBar.layer?.cornerRadius = 10
        chromeChoiceBar.layer?.borderWidth = 1
        [sourceCard, playerCard].forEach {
            $0.layer?.borderWidth = 1
            $0.layer?.shadowOpacity = 0.30
            $0.layer?.shadowRadius = 22
            $0.layer?.shadowOffset = .zero
        }
        sourceCard.isHidden = true
        chromeChoiceBar.isHidden = true
    }

    private func makeContentStack() -> NSStackView {
        logoBadge.image = NSApp.applicationIconImage
        logoBadge.imageScaling = .scaleProportionallyUpOrDown
        logoBadge.wantsLayer = true
        logoBadge.layer?.cornerRadius = 14
        logoBadge.layer?.masksToBounds = true
        logoBadge.widthAnchor.constraint(equalToConstant: 44).isActive = true
        logoBadge.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let brand = NSTextField(labelWithString: "Leanwave")
        brand.attributedStringValue = NSAttributedString(
            string: "LEANWAVE",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .kern: 4.0,
            ]
        )
        brand.tag = 501
        let tagline = NSTextField(labelWithString: "YouTube audio, without the visual noise.")
        tagline.font = .systemFont(ofSize: 10, weight: .regular)
        tagline.tag = 502
        let identity = NSStackView(views: [brand, tagline])
        identity.orientation = .vertical
        identity.alignment = .leading
        identity.spacing = 3
        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let windowControls = NSStackView(views: [minimizeButton, closeButton])
        windowControls.orientation = .horizontal
        windowControls.spacing = 8
        let header = NSStackView(views: [logoBadge, identity, headerSpacer, youtubeButton, themePopup, windowControls])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        header.heightAnchor.constraint(equalToConstant: 48).isActive = true

        sourceCaption.font = .systemFont(ofSize: 10, weight: .semibold)
        sourceCaption.tag = 503
        let inputRow = NSStackView(views: [urlField, playButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 10
        urlField.heightAnchor.constraint(equalToConstant: 42).isActive = true
        playButton.widthAnchor.constraint(equalToConstant: 96).isActive = true

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
            sourceStack.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 18),
            sourceStack.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -18),
            sourceStack.centerYAnchor.constraint(equalTo: sourceCard.centerYAnchor),
        ])

        let titleRow = NSStackView(views: [audioIndicator, titleLabel, audioIndicatorRight])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        let statusRow = NSStackView(views: [loadingIndicator, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8
        let titleStack = NSStackView(views: [titleRow, statusRow])
        titleStack.orientation = .vertical
        titleStack.alignment = .centerX
        titleStack.spacing = 4
        nowPlayingStack = titleStack

        let chromePrompt = NSTextField(labelWithString: "Chrome")
        chromePrompt.font = .systemFont(ofSize: 11, weight: .semibold)
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
        elapsedLabel.widthAnchor.constraint(equalToConstant: 46).isActive = true
        durationLabel.widthAnchor.constraint(equalToConstant: 46).isActive = true

        let playContainer = NSView()
        playContainer.addSubview(pulseRing)
        playContainer.addSubview(playPauseButton)
        pulseRing.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        pulseRing.layer?.cornerRadius = 25
        pulseRing.layer?.borderWidth = 2
        NSLayoutConstraint.activate([
            playContainer.widthAnchor.constraint(equalToConstant: 54),
            playContainer.heightAnchor.constraint(equalToConstant: 54),
            pulseRing.centerXAnchor.constraint(equalTo: playContainer.centerXAnchor),
            pulseRing.centerYAnchor.constraint(equalTo: playContainer.centerYAnchor),
            pulseRing.widthAnchor.constraint(equalToConstant: 50),
            pulseRing.heightAnchor.constraint(equalToConstant: 50),
            playPauseButton.centerXAnchor.constraint(equalTo: playContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: playContainer.centerYAnchor),
        ])

        let transport = NSStackView(views: [backButton, playContainer, forwardButton])
        transport.orientation = .horizontal
        transport.alignment = .centerY
        transport.spacing = 10

        let volume = NSStackView(views: [muteButton, volumeSlider])
        volume.orientation = .horizontal
        volume.alignment = .centerY
        volume.spacing = 10
        volumeSlider.widthAnchor.constraint(equalToConstant: 105).isActive = true

        let controlSpacer = NSView()
        controlSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let controls = NSStackView(views: [transport, stopButton, controlSpacer, volume])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12

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
            playerStack.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 18),
            playerStack.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -18),
            playerStack.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 6),
            playerStack.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -6),
        ])

        let footer = NSView()
        footer.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = NSStackView(views: [header, sourceCard, playerCard, footer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sourceCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        playerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sourceCard.heightAnchor.constraint(equalToConstant: 132).isActive = true
        playerCard.heightAnchor.constraint(equalToConstant: 132).isActive = true
        return stack
    }

    private func configureTextButton(_ button: NSButton, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: button === linkButton ? 15 : 12, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = button === linkButton ? 14 : 10
        button.heightAnchor.constraint(equalToConstant: button === playButton ? 42 : (button === linkButton ? 34 : 28)).isActive = true
        if button === linkButton { button.widthAnchor.constraint(equalToConstant: 100).isActive = true }
        if button !== playButton {
            button.contentTintColor = .labelColor
        }
    }

    private func configureWindowButton(_ button: NSButton, label: String, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.font = .systemFont(ofSize: 24, weight: .light)
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
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
        let size: CGFloat
        if button === playPauseButton {
            size = 48
        } else if button === youtubeButton {
            size = 42
        } else {
            size = 40
        }
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
        (view as? AuroraBackgroundView)?.apply(accent: accent)
        sourceCard.apply(accent: accent)
        playerCard.apply(accent: accent)
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
        audioIndicatorRight.contentTintColor = accent
        seekSlider.trackFillColor = accent
        volumeSlider.trackFillColor = accent
        [backButton, forwardButton, stopButton, muteButton, youtubeButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.17, alpha: 0.90).cgColor
            $0.layer?.borderWidth = 1
            $0.layer?.borderColor = accent.withAlphaComponent(0.24).cgColor
            $0.layer?.shadowColor = accent.cgColor
            $0.layer?.shadowOpacity = 0.16
            $0.layer?.shadowRadius = 8
            $0.layer?.shadowOffset = .zero
        }
        playPauseButton.contentTintColor = .white
        playPauseButton.layer?.backgroundColor = accent.withAlphaComponent(0.28).cgColor
        playPauseButton.layer?.borderWidth = 1.5
        playPauseButton.layer?.borderColor = accent.withAlphaComponent(0.90).cgColor
        playPauseButton.layer?.shadowColor = accent.cgColor
        playPauseButton.layer?.shadowOpacity = 0.55
        playPauseButton.layer?.shadowRadius = 14
        playPauseButton.layer?.shadowOffset = .zero
        playButton.contentTintColor = NSColor(palette.background)
        playButton.layer?.backgroundColor = accent.cgColor
        [linkButton, pasteButton, fetchButton, closeTabChoiceButton, quitChromeChoiceButton, keepOpenChoiceButton].forEach {
            $0.contentTintColor = NSColor(palette.primaryText)
            $0.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.17, alpha: 0.92).cgColor
        }
        linkButton.layer?.borderWidth = 1.5
        linkButton.layer?.borderColor = accent.withAlphaComponent(0.75).cgColor
        linkButton.layer?.shadowColor = accent.cgColor
        linkButton.layer?.shadowOpacity = 0.45
        linkButton.layer?.shadowRadius = 12
        linkButton.layer?.shadowOffset = .zero
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
        titleLabel.stringValue = state.phase == .idle ? "Ready to play" : state.title
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
            statusLabel.stringValue = "Open a YouTube video to load audio."
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = false
            audioIndicatorRight.isHidden = false
            audioIndicator.alphaValue = 0.72
            audioIndicatorRight.alphaValue = 0.72
        case .loading:
            statusLabel.stringValue = "Connecting to the audio stream…"
            loadingIndicator.startAnimation(nil)
            audioIndicator.isHidden = false
            audioIndicatorRight.isHidden = false
            audioIndicator.alphaValue = 0.42
            audioIndicatorRight.alphaValue = 0.42
        case .playing: statusLabel.stringValue = state.isPaused ? "Paused" : "Playing audio only"
        case .failed(let message):
            statusLabel.stringValue = message
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = false
            audioIndicatorRight.isHidden = false
            audioIndicator.alphaValue = 0.42
            audioIndicatorRight.alphaValue = 0.42
        }

        if state.phase == .playing {
            loadingIndicator.stopAnimation(nil)
            audioIndicator.isHidden = false
            audioIndicatorRight.isHidden = false
            audioIndicator.alphaValue = state.isPaused ? 0.45 : 1
            audioIndicatorRight.alphaValue = state.isPaused ? 0.45 : 1
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
        audioIndicator.layer?.removeAnimation(forKey: "leanwave.wave")
        audioIndicatorRight.layer?.removeAnimation(forKey: "leanwave.wave")
        guard active else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.92
        animation.toValue = 1.08
        animation.duration = 1.15
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseRing.layer?.add(animation, forKey: "leanwave.pulse")

        let wave = CABasicAnimation(keyPath: "opacity")
        wave.fromValue = 0.45
        wave.toValue = 1.0
        wave.duration = 0.72
        wave.autoreverses = true
        wave.repeatCount = .infinity
        wave.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        audioIndicator.layer?.add(wave, forKey: "leanwave.wave")
        wave.beginTime = CACurrentMediaTime() + 0.22
        audioIndicatorRight.layer?.add(wave, forKey: "leanwave.wave")
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

private final class AuroraBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        CAGradientLayer()
    }

    func apply(accent: NSColor) {
        guard let gradient = layer as? CAGradientLayer else { return }
        let tintedBlack = accent.blended(withFraction: 0.88, of: .black) ?? .black
        gradient.colors = [
            NSColor(calibratedRed: 0.012, green: 0.024, blue: 0.043, alpha: 1).cgColor,
            tintedBlack.withAlphaComponent(1).cgColor,
            NSColor(calibratedRed: 0.008, green: 0.015, blue: 0.027, alpha: 1).cgColor,
        ]
        gradient.locations = [0, 0.46, 1]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.cornerRadius = 22
        gradient.borderWidth = 1
        gradient.borderColor = accent.withAlphaComponent(0.16).cgColor
    }
}

private final class AuroraCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        CAGradientLayer()
    }

    func apply(accent: NSColor) {
        guard let gradient = layer as? CAGradientLayer else { return }
        let tintedSurface = accent.blended(withFraction: 0.84, of: .black) ?? .black
        gradient.colors = [
            NSColor(calibratedRed: 0.075, green: 0.13, blue: 0.20, alpha: 0.97).cgColor,
            NSColor(calibratedRed: 0.025, green: 0.07, blue: 0.12, alpha: 0.99).cgColor,
            tintedSurface.withAlphaComponent(1).cgColor,
        ]
        gradient.locations = [0, 0.66, 1]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.cornerRadius = 22
        gradient.borderWidth = 1
        gradient.borderColor = accent.withAlphaComponent(0.34).cgColor
        gradient.shadowColor = accent.cgColor
        gradient.shadowOpacity = 0.22
        gradient.shadowRadius = 18
        gradient.shadowOffset = .zero
    }
}
