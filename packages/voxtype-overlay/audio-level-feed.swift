import Darwin
import Foundation

/// Subscribes to Voxtype's local 16-byte, native-endian audio level frames.
/// This reads level metadata only, never microphone audio or transcribed text.
final class AudioLevelFeed: @unchecked Sendable {
  struct Snapshot {
    var connected = false
    var amplitudes: [Float] = []
    var lastFrame = Date.distantPast
  }

  private let lock = NSLock()
  private var current = Snapshot()
  private let socketPath: String

  init(socketPath: String) {
    self.socketPath = socketPath
  }

  func snapshot() -> Snapshot {
    lock.lock()
    defer { lock.unlock() }
    return current
  }

  func clear() {
    lock.lock()
    current.amplitudes.removeAll(keepingCapacity: true)
    current.lastFrame = .distantPast
    lock.unlock()
  }

  func start() {
    DispatchQueue.global(qos: .utility).async { [self] in
      while true {
        readConnection()
        Thread.sleep(forTimeInterval: 0.5)
      }
    }
  }

  private func readConnection() {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let path = Array(socketPath.utf8CString)
    guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return }
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
      path.withUnsafeBytes { destination.copyBytes(from: $0) }
    }
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return }
    defer { close(fd) }
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
      }
    }
    guard connected else { return }
    lock.lock()
    current = Snapshot(connected: true)
    lock.unlock()
    defer {
      lock.lock()
      current = Snapshot()
      lock.unlock()
    }

    var pending = Data()
    var bytes = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = recv(fd, &bytes, bytes.count, 0)
      if count < 0 && errno == EINTR { continue }
      guard count > 0 else { return }
      pending.append(contentsOf: bytes.prefix(count))
      let frameCount = pending.count / 16
      guard frameCount > 0 else { continue }
      var amplitudes: [Float] = []
      pending.withUnsafeBytes { buffer in
        for offset in stride(from: 0, to: frameCount * 16, by: 16) {
          let minimum = buffer.loadUnaligned(fromByteOffset: offset + 4, as: Float.self)
          let maximum = buffer.loadUnaligned(fromByteOffset: offset + 8, as: Float.self)
          guard minimum.isFinite, maximum.isFinite else { continue }
          amplitudes.append(min(1, max(abs(minimum), abs(maximum))))
        }
      }
      pending = Data(pending.dropFirst(frameCount * 16))
      lock.lock()
      if !amplitudes.isEmpty {
        current.amplitudes.append(contentsOf: amplitudes)
        current.amplitudes = Array(current.amplitudes.suffix(90))
        current.lastFrame = Date()
      }
      lock.unlock()
    }
  }
}
