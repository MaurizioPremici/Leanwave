import Foundation
import Network

final class HTTPRangeProxy: @unchecked Sendable {
    private let remoteURL: URL
    private let headers: [String: String]
    private let queue = DispatchQueue(label: "com.mauriziopremici.leanwave.proxy")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var transfers: [Process] = []

    init(remoteURL: URL, headers: [String: String]) {
        self.remoteURL = remoteURL
        self.headers = headers
    }

    static func forwardedRangeHeader(for request: String) -> String {
        let rangeValue = request.components(separatedBy: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("range:") })?
            .split(separator: ":", maxSplits: 1)
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "bytes=", with: "")
        let bounds = rangeValue?.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let start = bounds?.first.flatMap { Int64($0) } ?? 0
        let requestedEnd = bounds.flatMap { $0.count == 2 ? Int64($0[1]) : nil }
        let (candidateEnd, overflowed) = start.addingReportingOverflow(512 * 1_024 - 1)
        let maximumEnd = overflowed ? Int64.max : candidateEnd
        let end = max(start, min(requestedEnd ?? maximumEnd, maximumEnd))
        return "Range: bytes=\(start)-\(end)"
    }

    func start() throws -> URL {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        self.listener = listener
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 3) == .success, let port = listener.port else {
            throw PlayerControllerError.launchFailed("Local audio proxy did not start.")
        }
        return URL(string: "http://127.0.0.1:\(port.rawValue)/audio")!
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            connections.forEach { $0.cancel() }
            connections.removeAll()
            transfers.forEach { if $0.isRunning { $0.terminate() } }
            transfers.removeAll()
        }
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self, let data else { connection.cancel(); return }
            var requestData = accumulated
            requestData.append(data)
            guard requestData.range(of: Data("\r\n\r\n".utf8)) != nil else {
                self.receiveRequest(on: connection, accumulated: requestData)
                return
            }
            guard let request = String(data: requestData, encoding: .utf8) else { connection.cancel(); return }
            self.startTransfer(request: request, connection: connection)
        }
    }

    private func startTransfer(request: String, connection: NWConnection) {
        let transfer = Process()
        transfer.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        var arguments = [
            "--silent", "--show-error", "--location", "--http1.1", "--include", "--raw",
            "--connect-timeout", "10", "--max-time", "120",
        ]
        if request.hasPrefix("HEAD ") { arguments.append("--head") }
        for (name, value) in headers { arguments += ["--header", "\(name): \(value)"] }
        arguments += ["--header", Self.forwardedRangeHeader(for: request)]
        arguments += ["--", remoteURL.absoluteString]
        transfer.arguments = arguments
        let output = Pipe()
        transfer.standardOutput = output
        transfer.standardError = FileHandle.nullDevice
        do {
            try transfer.run()
            transfers.append(transfer)
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let response = output.fileHandleForReading.readDataToEndOfFile()
                transfer.waitUntilExit()
                self?.queue.async { [weak self] in
                    self?.transfers.removeAll { $0 === transfer }
                    connection.send(content: response, contentContext: .defaultMessage, isComplete: true, completion: .contentProcessed { _ in connection.cancel() })
                }
            }
        } catch {
            connection.cancel()
        }
    }
}
