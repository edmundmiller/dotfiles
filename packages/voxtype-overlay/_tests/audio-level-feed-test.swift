import Darwin
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
  }
}

func eventually(_ message: String, _ condition: () -> Bool) {
  let deadline = Date().addingTimeInterval(3)
  while !condition() {
    require(Date() < deadline, message)
    Thread.sleep(forTimeInterval: 0.01)
  }
}

@main
enum AudioLevelFeedTest {
  static func main() {
    let path = "/tmp/voxtype-feed-test-\(getpid()).sock"
    defer { unlink(path) }
    let server = socket(AF_UNIX, SOCK_STREAM, 0)
    require(server >= 0, "create Unix socket")
    defer { close(server) }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      path.utf8CString.withUnsafeBytes { destination.copyBytes(from: $0) }
    }
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    require(bound == 0 && listen(server, 2) == 0, "listen on Unix socket")
    let feed = AudioLevelFeed(socketPath: path)
    feed.start()

    func acceptClient() -> Int32 {
      var descriptor = pollfd(fd: server, events: Int16(POLLIN), revents: 0)
      require(poll(&descriptor, 1, 3000) == 1, "client connects within three seconds")
      let client = accept(server, nil, nil)
      require(client >= 0, "accept client")
      return client
    }

    func sendBytes(_ bytes: [UInt8], to client: Int32) {
      let count = bytes.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
      require(count == bytes.count, "send complete test payload")
    }

    var client = acceptClient()
    // Independently encoded little-endian frames: seq 42, min -0.75,
    // max 0.125, peak -2.5; then seq 43, min -0.25, max 0.5, peak -6.
    let frames: [UInt8] = [
      42, 0, 0, 0, 0, 0, 64, 191, 0, 0, 0, 62, 0, 0, 32, 192,
      43, 0, 0, 0, 0, 0, 128, 190, 0, 0, 0, 63, 0, 0, 192, 192,
    ]
    sendBytes(Array(frames.prefix(7)), to: client)
    Thread.sleep(forTimeInterval: 0.05)
    require(feed.snapshot().amplitudes.isEmpty, "partial frame must not produce a level")
    sendBytes(Array(frames.dropFirst(7)), to: client)
    eventually("fragmented and coalesced frames preserve asymmetric peaks") {
      feed.snapshot().amplitudes == [0.75, 0.5]
    }
    require(feed.snapshot().connected, "connected while server stays open")

    feed.clear()
    require(feed.snapshot().amplitudes.isEmpty, "new recording clears old waveform")
    // 100 positive-only frames exercise bounded history and max polarity.
    let positiveFrame: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 62, 0, 0, 144, 193]
    sendBytes(Array(repeating: positiveFrame, count: 100).flatMap { $0 }, to: client)
    eventually("waveform retains only the most recent 90 levels") {
      feed.snapshot().amplitudes == Array(repeating: Float(0.125), count: 90)
    }
    sendBytes(Array(frames.prefix(5)), to: client)
    close(client)
    eventually("disconnect clears stale waveform and connection state") {
      !feed.snapshot().connected && feed.snapshot().amplitudes.isEmpty
    }
    client = acceptClient()
    sendBytes(Array(frames.suffix(16)), to: client)
    eventually("reconnect discards previous connection's partial frame") {
      feed.snapshot().amplitudes == [0.5]
    }
    close(client)
    print("PASS: audio level feed fragmentation, peak polarity, history, clearing and reconnection")
  }
}
