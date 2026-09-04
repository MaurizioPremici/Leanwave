import Darwin
import Foundation
import XCTest
@testable import LeanwaveCore

final class UnixSocketConnectionTests: XCTestCase {
    func testReadsAndWritesNewlineDelimitedIPCData() throws {
        var descriptors: [Int32] = [-1, -1]
        XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors), 0)
        let received = expectation(description: "client receives data")
        let callbackQueue = DispatchQueue(label: "leanwave.socket.test")
        let client = UnixSocketConnection(
            connectedFileDescriptor: descriptors[0],
            queue: callbackQueue,
            onData: { data in
                XCTAssertEqual(String(data: data, encoding: .utf8), "{\"event\":\"playback-restart\"}\n")
                received.fulfill()
            },
            onFailure: { error in XCTFail(error.localizedDescription) }
        )

        let inbound = Data("{\"event\":\"playback-restart\"}\n".utf8)
        _ = inbound.withUnsafeBytes { write(descriptors[1], $0.baseAddress, $0.count) }
        wait(for: [received], timeout: 2)

        client.send(Data("{\"command\":[\"stop\"]}\n".utf8))
        var pollDescriptor = pollfd(fd: descriptors[1], events: Int16(POLLIN), revents: 0)
        XCTAssertEqual(poll(&pollDescriptor, 1, 2_000), 1)
        var buffer = [UInt8](repeating: 0, count: 128)
        let count = read(descriptors[1], &buffer, buffer.count)
        XCTAssertEqual(String(decoding: buffer.prefix(count), as: UTF8.self), "{\"command\":[\"stop\"]}\n")

        client.cancel()
        close(descriptors[1])
    }
}
