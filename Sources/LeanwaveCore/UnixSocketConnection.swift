import Darwin
import Foundation

public enum UnixSocketError: Error, LocalizedError {
    case pathTooLong
    case systemCall(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .pathTooLong:
            "The player control socket path is too long."
        case .systemCall(let call, let code):
            "Unix socket \(call) failed: \(String(cString: strerror(code)))."
        }
    }
}

public final class UnixSocketConnection: @unchecked Sendable {
    public typealias DataHandler = @Sendable (Data) -> Void
    public typealias FailureHandler = @Sendable (Error) -> Void

    private let fileDescriptor: Int32
    private let queue: DispatchQueue
    private let onData: DataHandler
    private let onFailure: FailureHandler
    private let lock = NSLock()
    private var source: DispatchSourceRead?
    private var cancelled = false

    public convenience init(
        path: String,
        queue: DispatchQueue,
        onData: @escaping DataHandler,
        onFailure: @escaping FailureHandler
    ) throws {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw UnixSocketError.systemCall("socket", errno)
        }

        var address = sockaddr_un()
        let pathBytes = Array(path.utf8) + [0]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            close(descriptor)
            throw UnixSocketError.pathTooLong
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: pathBytes)
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let code = errno
            close(descriptor)
            throw UnixSocketError.systemCall("connect", code)
        }

        self.init(
            connectedFileDescriptor: descriptor,
            queue: queue,
            onData: onData,
            onFailure: onFailure
        )
    }

    init(
        connectedFileDescriptor: Int32,
        queue: DispatchQueue,
        onData: @escaping DataHandler,
        onFailure: @escaping FailureHandler
    ) {
        fileDescriptor = connectedFileDescriptor
        self.queue = queue
        self.onData = onData
        self.onFailure = onFailure

        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: connectedFileDescriptor,
            queue: queue
        )
        source = readSource
        readSource.setEventHandler { [weak self] in self?.readAvailableData() }
        readSource.setCancelHandler { close(connectedFileDescriptor) }
        readSource.resume()
    }

    deinit {
        cancel()
    }

    public func send(_ data: Data) {
        queue.async { [weak self] in self?.writeAll(data) }
    }

    public func cancel() {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        let source = self.source
        self.source = nil
        lock.unlock()
        source?.cancel()
    }

    private func readAvailableData() {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = Darwin.read(fileDescriptor, &buffer, buffer.count)
        if count > 0 {
            onData(Data(buffer.prefix(count)))
        } else if count == 0 {
            cancel()
        } else if errno != EAGAIN && errno != EINTR {
            onFailure(UnixSocketError.systemCall("read", errno))
            cancel()
        }
    }

    private func writeAll(_ data: Data) {
        do {
            try data.withUnsafeBytes { rawBuffer in
                guard var pointer = rawBuffer.baseAddress else { return }
                var remaining = rawBuffer.count
                while remaining > 0 {
                    let count = Darwin.write(fileDescriptor, pointer, remaining)
                    guard count >= 0 else {
                        if errno == EINTR { continue }
                        throw UnixSocketError.systemCall("write", errno)
                    }
                    remaining -= count
                    pointer = pointer.advanced(by: count)
                }
            }
        } catch {
            onFailure(error)
        }
    }
}
