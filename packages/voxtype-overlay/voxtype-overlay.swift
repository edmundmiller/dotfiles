import AppKit

/// Click-through recording HUD. The daemon still owns hotkeys, audio and typing.
final class RecordingPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class RecordingView: NSView {
  var recording = true
  var elapsed = 0
  var amplitudes: [Float] = []
  var audioMissing = false
  var notchHeight: CGFloat = 0
  var collapsedWidth: CGFloat = 160
  var revealProgress: CGFloat = 0

  override func draw(_ dirtyRect: NSRect) {
    let width = collapsedWidth + (bounds.width - collapsedWidth) * revealProgress
    let height = notchHeight + 40 * revealProgress
    let rect = NSRect(
      x: (bounds.width - width) / 2, y: bounds.height - height,
      width: width, height: height)
    let island: NSBezierPath
    if notchHeight > 0 {
      // Concave shoulders join the screen edge; the bottom rounds like the physical notch.
      let shoulder: CGFloat = 8
      let radius: CGFloat = 16
      island = NSBezierPath()
      island.move(to: NSPoint(x: rect.minX, y: rect.maxY))
      island.curve(
        to: NSPoint(x: rect.minX + shoulder, y: rect.maxY - shoulder),
        controlPoint1: NSPoint(x: rect.minX + shoulder, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.minX + shoulder, y: rect.maxY))
      island.line(to: NSPoint(x: rect.minX + shoulder, y: rect.minY + radius))
      island.curve(
        to: NSPoint(x: rect.minX + shoulder + radius, y: rect.minY),
        controlPoint1: NSPoint(x: rect.minX + shoulder, y: rect.minY + radius * 0.45),
        controlPoint2: NSPoint(x: rect.minX + shoulder + radius * 0.45, y: rect.minY))
      island.line(to: NSPoint(x: rect.maxX - shoulder - radius, y: rect.minY))
      island.curve(
        to: NSPoint(x: rect.maxX - shoulder, y: rect.minY + radius),
        controlPoint1: NSPoint(x: rect.maxX - shoulder - radius * 0.45, y: rect.minY),
        controlPoint2: NSPoint(x: rect.maxX - shoulder, y: rect.minY + radius * 0.45))
      island.line(to: NSPoint(x: rect.maxX - shoulder, y: rect.maxY - shoulder))
      island.curve(
        to: NSPoint(x: rect.maxX, y: rect.maxY),
        controlPoint1: NSPoint(x: rect.maxX - shoulder, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.maxX - shoulder, y: rect.maxY))
      island.close()
    } else {
      island = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
    }
    NSColor.black.setFill()
    island.fill()

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    island.addClip()
    // Never put text or waveform behind the camera, including during expansion.
    NSBezierPath(
      rect: NSRect(
        x: 0, y: 0, width: bounds.width,
        height: bounds.height - notchHeight)
    ).addClip()
    NSGraphicsContext.current?.cgContext.setAlpha(revealProgress)
    let contentTransform = NSAffineTransform()
    contentTransform.translateX(by: (bounds.width - 224) / 2, yBy: rect.minY)
    contentTransform.concat()

    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if recording {
      let accent =
        audioMissing
        ? NSColor.systemOrange : NSColor(srgbRed: 1, green: 0.35, blue: 0.33, alpha: 1)
      if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
          .applying(.init(paletteColors: [accent]))
        image.withSymbolConfiguration(configuration)?.draw(
          in: NSRect(x: 16, y: 12, width: 12, height: 16))
      }
    } else {
      for index in 0..<3 {
        let phase = ProcessInfo.processInfo.systemUptime * 4 - Double(index) * 0.8
        let opacity = reduceMotion ? 0.7 : 0.4 + 0.5 * (sin(phase) + 1) / 2
        NSColor.white.withAlphaComponent(opacity).setFill()
        NSBezierPath(ovalIn: NSRect(x: 14 + index * 6, y: 18, width: 3, height: 3)).fill()
      }
    }

    if !recording || audioMissing {
      let title = recording ? "No audio" : "Transcribing"
      (title as NSString).draw(
        at: NSPoint(x: 44, y: 13),
        withAttributes: [
          .font: NSFont.systemFont(ofSize: 12, weight: .medium),
          .foregroundColor: NSColor.white.withAlphaComponent(0.9),
        ])
    }
    (String(format: "%d:%02d", elapsed / 60, elapsed % 60) as NSString).draw(
      at: NSPoint(x: 182, y: 13),
      withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor.white.withAlphaComponent(0.55),
      ]
    )

    guard recording else { return }
    if audioMissing {
      NSColor.white.withAlphaComponent(0.3).setFill()
      for index in 0..<16 {
        NSBezierPath(ovalIn: NSRect(x: 106 + index * 4, y: 19, width: 2, height: 2)).fill()
      }
      return
    }
    NSColor.white.withAlphaComponent(0.9).setFill()
    if reduceMotion {
      let level = min(1, CGFloat(amplitudes.suffix(10).max() ?? 0) * 4)
      NSBezierPath(
        roundedRect: NSRect(x: 48, y: 17, width: max(3, 118 * level), height: 6), xRadius: 3,
        yRadius: 3
      ).fill()
    } else {
      let padded = Array(repeating: Float(0), count: max(0, 90 - amplitudes.count)) + amplitudes
      for index in 0..<30 {
        let amplitude = padded[(index * 3)..<(index * 3 + 3)].max() ?? 0
        let height = max(2, min(22, CGFloat(amplitude) * 88))
        NSBezierPath(
          roundedRect: NSRect(
            x: 48 + CGFloat(index) * 4, y: 20 - height / 2, width: 2, height: height),
          xRadius: 1, yRadius: 1
        ).fill()
      }
    }
  }
}

final class OverlayDelegate: NSObject, NSApplicationDelegate {
  private let runtimeDirectory: URL
  private let preview: String?
  private let feed: AudioLevelFeed
  private let view = RecordingView(frame: NSRect(x: 0, y: 0, width: 224, height: 40))
  private var panel: RecordingPanel!
  private var timer: Timer?
  private var previousState = "idle"
  private var recordingStarted = Date()
  private var elapsed = 0
  private var lastAnimationTime = ProcessInfo.processInfo.systemUptime

  init(runtimeDirectory: URL, preview: String?) {
    self.runtimeDirectory = runtimeDirectory
    self.preview = preview
    feed = AudioLevelFeed(socketPath: runtimeDirectory.appendingPathComponent("audio.sock").path)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    panel = RecordingPanel(
      contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    panel.title = "Voxtype recording overlay"
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.appearance = NSAppearance(named: .darkAqua)
    panel.animationBehavior = .none

    panel.contentView = view
    view.setAccessibilityElement(true)
    view.setAccessibilityRole(.staticText)
    NotificationCenter.default.addObserver(
      self, selector: #selector(screenParametersChanged),
      name: NSApplication.didChangeScreenParametersNotification, object: nil)
    if preview == nil { feed.start() }
    timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.refresh() }
    RunLoop.main.add(timer!, forMode: .common)
    refresh()
  }

  @objc private func screenParametersChanged() {
    panel.orderOut(nil)
    view.revealProgress = 0
  }

  private func positionPanel() {
    // Choose once per recording so moving the pointer cannot move the island.
    guard
      let screen = NSScreen.screens.first(where: {
        NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
      }) ?? NSScreen.main
    else { return }
    view.notchHeight = screen.safeAreaInsets.top
    var center = screen.frame.midX
    if view.notchHeight > 0,
      let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
    {
      view.collapsedWidth = right.minX - left.maxX + 16
      center = (left.maxX + right.minX) / 2
    } else {
      view.collapsedWidth = 160
    }
    let width = view.notchHeight > 0 ? max(240, view.collapsedWidth) : 224
    let height = view.notchHeight + 40
    let top = view.notchHeight > 0 ? screen.frame.maxY : screen.visibleFrame.maxY - 8
    panel.setFrame(
      NSRect(
        x: center - width / 2, y: top - height,
        width: width, height: height), display: false)
  }

  private func updateReveal(visible: Bool) {
    let now = ProcessInfo.processInfo.systemUptime
    let delta = min(0.1, now - lastAnimationTime)
    lastAnimationTime = now
    let target: CGFloat = visible ? 1 : 0
    // Retarget from the current shape so a quick restart reverses a closing island.
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      view.revealProgress = target
    } else {
      view.revealProgress += (target - view.revealProgress) * CGFloat(1 - exp(-18 * delta))
      if abs(target - view.revealProgress) < 0.002 { view.revealProgress = target }
    }
    panel.alphaValue = view.notchHeight > 0 ? 1 : view.revealProgress
    view.needsDisplay = true
    if view.revealProgress != target { panel.invalidateShadow() }
    if !visible && view.revealProgress == 0 { panel.orderOut(nil) }
  }

  private func refresh() {
    let snapshot = feed.snapshot()
    var state: String
    if let preview {
      state = preview == "transcribing" ? "transcribing" : "recording"
    } else {
      state =
        snapshot.connected
        ? ((try? String(
          contentsOf: runtimeDirectory.appendingPathComponent("state"), encoding: .utf8))?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? "idle")
        : "idle"
    }
    // Streaming is active capture too; keep its timer, waveform and accessibility in sync.
    if state == "streaming" { state = "recording" }
    guard state == "recording" || state == "transcribing" else {
      updateReveal(visible: false)
      if previousState != "idle" { feed.clear() }
      previousState = "idle"
      return
    }

    if state == "recording", previousState != "recording" {
      recordingStarted = Date()
      elapsed = 0
    }
    if !panel.isVisible {
      positionPanel()
      panel.orderFrontRegardless()
    }
    updateReveal(visible: true)
    if state == "recording" { elapsed = Int(Date().timeIntervalSince(recordingStarted)) }
    view.recording = state == "recording"
    view.elapsed = preview == nil ? elapsed : 12
    view.audioMissing =
      preview == "silent"
      || (preview == nil && Date().timeIntervalSince(snapshot.lastFrame) > 0.7 && elapsed > 0)
    if preview == "recording" {
      view.amplitudes = (0..<90).map { index in
        Float(
          0.025 + abs(sin(Double(index) * 0.23)) * (0.04 + 0.16 * abs(sin(Double(index) * 0.07))))
      }
    } else {
      view.amplitudes = snapshot.amplitudes
    }
    if previousState != state {
      view.setAccessibilityLabel(
        state == "recording" ? "Voxtype recording" : "Voxtype transcribing")
    }
    previousState = state
    view.needsDisplay = true
  }
}

@main
enum VoxtypeOverlay {
  static func main() {
    var directory = URL(
      fileURLWithPath: ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? "/tmp"
    ).appendingPathComponent("voxtype")
    var preview: String?
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
      let argument = args.removeFirst()
      if argument == "--help" {
        print(
          "Usage: voxtype-overlay [--runtime-dir PATH] [--preview recording|transcribing|silent]")
        return
      }
      guard !args.isEmpty else { usageError() }
      let value = args.removeFirst()
      switch argument {
      case "--runtime-dir": directory = URL(fileURLWithPath: value)
      case "--preview" where ["recording", "transcribing", "silent"].contains(value):
        preview = value
      default: usageError()
      }
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = OverlayDelegate(runtimeDirectory: directory, preview: preview)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }

  private static func usageError() -> Never {
    fputs("voxtype-overlay: invalid arguments; use --help\n", stderr)
    exit(64)
  }
}
