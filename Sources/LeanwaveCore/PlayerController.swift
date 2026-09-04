import Foundation
import Network

public enum PlayerControllerError: Error, LocalizedError {
    case missingDependency(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingDependency(let name):
            "Required tool not found: \(name). Install it with Homebrew."
        case .launchFailed(let message):
            "Unable to start audio playback: \(message)"
        }
    }
}

public final class PlayerController: @unchecked Sendable {
    public typealias StateHandler = @Sendable (PlayerState) -> Void

    private let queue = DispatchQueue(label: "com.mauriziopremici.leanwave.player")
    private let stateLock = NSLock()
    private var currentState = PlayerState()
    private var process: Process?
    private var connection: NWConnection?
    private var socketPath: String?
    private var receiveBuffer = Data()
    private var requestID = 0
    private var sessionID = UUID()

    public var onStateChange: StateHandler?

    public init() {}

    deinit {
        connection?.cancel()
        if let process, process.isRunning { process.terminate() }
        if let socketPath { try? FileManager.default.removeItem(atPath: socketPath) }
    }

    public var state: PlayerState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentState
    }

    public func play(url: YouTubeURL) throws {
        guard let mpvPath = ExecutableLocator.resolve(named: "mpv") else {
            throw PlayerControllerError.missingDependency("mpv")
        }
        guard let ytdlpPath = ExecutableLocator.resolve(named: "yt-dlp") else {
            throw PlayerControllerError.missingDependency("yt-dlp")
        }

        try queue.sync {
            stopLocked(emitEnded: false)
            let session = UUID()
            sessionID = session
            let path = "/tmp/leanwave-\(session.uuidString).sock"
            socketPath = path
            receiveBuffer.removeAll(keepingCapacity: true)
            requestID = 0
            emit(.loading)

            let newProcess = Process()
            newProcess.executableURL = URL(fileURLWithPath: mpvPath)
            newProcess.arguments = MPVLaunchConfiguration.arguments(
                url: url.normalizedString,
                socketPath: path,
                ytdlpPath: ytdlpPath
            ) + ["--really-quiet"]
            newProcess.standardOutput = FileHandle.nullDevice
            newProcess.standardError = FileHandle.nullDevice
            newProcess.terminationHandler = { [weak self] _ in
                guard let controller = self else { return }
                controller.queue.async { controller.processDidExit(session: session) }
            }
            do {
                try newProcess.run()
            } catch {
                cleanupSocket(path)
                emit(.failed(error.localizedDescription))
                throw PlayerControllerError.launchFailed(error.localizedDescription)
            }
            process = newProcess
            connectWhenReady(path: path, session: session, remainingAttempts: 100)
        }
    }

    public func togglePause() {
        let paused = state.isPaused
        queue.async { self.send(.setPause(!paused)) }
    }

    public func seek(seconds: Double) {
        queue.async { self.send(.seekRelative(seconds)) }
    }

    public func setVolume(_ volume: Double) {
        queue.async { self.send(.setVolume(volume)) }
    }

    public func toggleMute() {
        let muted = state.isMuted
        queue.async { self.send(.setMute(!muted)) }
    }

    public func markCloseChoiceHandled() {
        queue.async { self.emit(.closeChoiceHandled) }
    }

    public func stop() {
        queue.async { self.stopLocked(emitEnded: true) }
    }

    private func connectWhenReady(path: String, session: UUID, remainingAttempts: Int) {
        guard session == sessionID else { return }
        guard FileManager.default.fileExists(atPath: path) else {
            if remainingAttempts > 0 {
                queue.asyncAfter(deadline: .now() + 0.05) {
                    self.connectWhenReady(
                        path: path,
                        session: session,
                        remainingAttempts: remainingAttempts - 1
                    )
                }
            } else {
                emit(.failed("The player control socket did not become ready."))
                stopLocked(emitEnded: false)
            }
            return
        }

        let newConnection = NWConnection(to: .unix(path: path), using: .tcp)
        connection = newConnection
        newConnection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.queue.async {
                guard session == self.sessionID else { return }
                switch state {
                case .ready:
                    self.observeProperties()
                    self.send(.setVolume(self.state.volume))
                    self.send(.setPause(false))
                    self.receiveNext(session: session)
                case .failed(let error):
                    self.emit(.failed("Player connection failed: \(error.localizedDescription)"))
                default:
                    break
                }
            }
        }
        newConnection.start(queue: queue)
    }

    private func observeProperties() {
        let names = ["time-pos", "duration", "pause", "mute", "volume", "media-title"]
        for (index, name) in names.enumerated() {
            send(.observeProperty(id: index + 1, name: name))
        }
    }

    private func receiveNext(session: UUID) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            self.queue.async {
                guard session == self.sessionID else { return }
                if let data { self.consume(data) }
                if let error {
                    self.emit(.failed("Player connection failed: \(error.localizedDescription)"))
                    return
                }
                if !isComplete { self.receiveNext(session: session) }
            }
        }
    }

    private func consume(_ data: Data) {
        receiveBuffer.append(data)
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let lineData = receiveBuffer[..<newline]
            receiveBuffer.removeSubrange(...newline)
            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }
            if let event = try? MPVEventParser.parse(line) { emit(event) }
        }
    }

    private func send(_ command: MPVCommand) {
        guard let connection else { return }
        requestID += 1
        guard let data = try? command.encoded(requestID: requestID) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func emit(_ event: PlayerEvent) {
        stateLock.lock()
        currentState = PlayerEventReducer.reduce(state: currentState, event: event)
        let snapshot = currentState
        let handler = onStateChange
        stateLock.unlock()
        if let handler { DispatchQueue.main.async { handler(snapshot) } }
    }

    private func stopLocked(emitEnded: Bool) {
        sessionID = UUID()
        if connection != nil { send(.stop) }
        connection?.cancel()
        connection = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        if let socketPath { cleanupSocket(socketPath) }
        socketPath = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        if emitEnded { emit(.ended) }
    }

    private func processDidExit(session: UUID) {
        guard session == sessionID else { return }
        connection?.cancel()
        connection = nil
        process = nil
        if let socketPath { cleanupSocket(socketPath) }
        socketPath = nil
        if case .failed = state.phase { return }
        emit(.ended)
    }

    private func cleanupSocket(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
