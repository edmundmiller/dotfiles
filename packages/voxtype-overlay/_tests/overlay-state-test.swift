// Requires a logged-in macOS GUI session, not a Nix build sandbox.
// Run: swift packages/voxtype-overlay/_tests/overlay-state-test.swift /path/to/voxtype-overlay
// Uses a disposable daemon socket and state file; never records or transcribes audio.
import AppKit
import Darwin

struct OverlayTestFailure: Error {
  let message: String
}

func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw OverlayTestFailure(message: message) }
}

func runOverlayStateTest() throws {
  try require(CommandLine.arguments.count == 2, "provide the overlay executable path")
  let directory = URL(fileURLWithPath: "/tmp/voxtype-state-test-\(getpid())")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directory) }

  func writeState(_ state: String) throws {
    try state.write(
      to: directory.appendingPathComponent("state"), atomically: true, encoding: .utf8)
  }
  try writeState("idle")

  let server = socket(AF_UNIX, SOCK_STREAM, 0)
  try require(server >= 0, "create daemon socket")
  defer { close(server) }
  var address = sockaddr_un()
  address.sun_family = sa_family_t(AF_UNIX)
  address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
  let path = directory.appendingPathComponent("audio.sock").path
  withUnsafeMutableBytes(of: &address.sun_path) { destination in
    path.utf8CString.withUnsafeBytes { destination.copyBytes(from: $0) }
  }
  let bound = withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
  }
  try require(bound == 0 && listen(server, 1) == 0, "listen for overlay connection")

  let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
  let overlay = Process()
  overlay.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
  overlay.arguments = ["--runtime-dir", directory.path]
  try overlay.run()
  defer {
    if overlay.isRunning { overlay.terminate() }
    overlay.waitUntilExit()
  }
  var descriptor = pollfd(fd: server, events: Int16(POLLIN), revents: 0)
  try require(poll(&descriptor, 1, 3000) == 1, "overlay connects to daemon socket")
  var client = accept(server, nil, nil)
  try require(client >= 0, "accept overlay connection")
  defer { if client >= 0 { close(client) } }
  // Remove the listening address so the final disconnect cannot reconnect to a dead daemon.
  unlink(path)
  // One independently encoded frame: sequence 0, min 0, max 0.125, peak -18 dBFS.
  let frame: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 62, 0, 0, 144, 193]
  let sent = frame.withUnsafeBytes { send(client, $0.baseAddress, $0.count, 0) }
  try require(sent == 16, "send audio level frame")

  func visible() -> Bool {
    let windows =
      CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
      as? [[String: Any]] ?? []
    return windows.contains {
      ($0[kCGWindowOwnerPID as String] as? Int32) == overlay.processIdentifier
        && ($0[kCGWindowAlpha as String] as? Double ?? 0) > 0
    }
  }
  func expectVisibility(_ expected: Bool, _ message: String) throws {
    // Allow state polling and the expand/retract animation to finish first.
    Thread.sleep(forTimeInterval: 0.6)
    let deadline = Date().addingTimeInterval(2)
    while visible() != expected && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.02)
    }
    try require(overlay.isRunning && visible() == expected, message)
  }

  try expectVisibility(false, "idle starts hidden")
  try writeState("streaming\n")
  try expectVisibility(true, "streaming capture shows the recording indicator")
  try writeState("transcribing")
  try expectVisibility(true, "transcribing keeps the indicator visible")
  try writeState("idle")
  try expectVisibility(false, "idle retracts the indicator")
  try writeState("recording")
  try expectVisibility(true, "ordinary recording still shows the indicator")
  try writeState("streaming")
  try expectVisibility(true, "recording-to-streaming transition stays visible")
  close(client)
  client = -1
  try expectVisibility(false, "disconnected daemon hides even a stale streaming state")
  try require(
    NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost,
    "state transitions must not steal focus")
}

do {
  try runOverlayStateTest()
  print("PASS: streaming, recording, transcribing, idle, disconnect and focus preservation")
} catch {
  fputs("FAIL: \(error)\n", stderr)
  exit(1)
}
