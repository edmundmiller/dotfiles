import AppKit
import ApplicationServices

// Like Hex's permission guide, offer the installed app as a real file-URL drag,
// not an image of an app or a path copied to the user's clipboard.
private final class AccessibilityAppTile: NSView, NSDraggingSource {
    let bundleURL: URL
    private let icon: NSImage
    private var pressedAt: NSPoint?

    init(frame: NSRect, bundleURL: URL) {
        self.bundleURL = bundleURL
        icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityLabel("TinyType app. Drag into the permission list, or use Show in Finder.")
    }

    required init?(coder: NSCoder) { fatalError("AccessibilityAppTile requires an app URL") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        icon.draw(in: NSRect(x: 10, y: 8, width: 32, height: 32))
        ("TinyType" as NSString).draw(at: NSPoint(x: 54, y: 16), withAttributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.labelColor,
        ])
        ("Drag to System Settings ↑" as NSString).draw(at: NSPoint(x: 230, y: 17), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    override func mouseDown(with event: NSEvent) { pressedAt = event.locationInWindow }
    override func mouseUp(with event: NSEvent) { pressedAt = nil }
    override func mouseDragged(with event: NSEvent) {
        guard let start = pressedAt,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 else { return }
        pressedAt = nil
        let item = NSDraggingItem(pasteboardWriter: bundleURL as NSURL)
        guard let bitmap = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: bitmap)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

/// A nonactivating drag guide stays beside System Settings until permission is allowed.
final class AccessibilityGuide: NSObject {
    private var panel: NSPanel?
    private var timer: Timer?
    private var sawSettings = false

    static var listName: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
            ? "Device Control and Data Access" : "Accessibility"
    }

    private var appURL: URL? {
        let url = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard url.pathExtension == "app", Bundle(url: url)?.bundleIdentifier == "dev.edmundmiller.tinytype" else { return nil }
        return url
    }

    @objc func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        sawSettings = false
    }

    @objc private func revealApp() {
        if let appURL { NSWorkspace.shared.activateFileViewerSelecting([appURL]) }
    }

    func show() {
        hide()
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        guard !AXIsProcessTrusted(), let appURL else { return }
        let size = NSSize(width: 500, height: 190)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "TinyType Accessibility setup"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        content.layer?.cornerRadius = 16
        panel.contentView = content

        let instruction = NSTextField(wrappingLabelWithString: "Drag TinyType into \(Self.listName), then switch it on.")
        instruction.font = .systemFont(ofSize: 14, weight: .medium)
        instruction.frame = NSRect(x: 18, y: 134, width: 436, height: 38)
        content.addSubview(instruction)
        content.addSubview(AccessibilityAppTile(frame: NSRect(x: 18, y: 76, width: 464, height: 48), bundleURL: appURL))
        let recovery = NSTextField(labelWithString: "Already listed but stuck? Remove the old TinyType row first.")
        recovery.font = .systemFont(ofSize: 12)
        recovery.textColor = .secondaryLabelColor
        recovery.frame = NSRect(x: 18, y: 46, width: 464, height: 18)
        content.addSubview(recovery)
        let note = NSTextField(labelWithString: "Closes automatically when allowed.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 18, y: 17, width: 270, height: 17)
        content.addSubview(note)
        let reveal = NSButton(title: "Show in Finder", target: self, action: #selector(revealApp))
        reveal.bezelStyle = .rounded
        reveal.frame = NSRect(x: 345, y: 9, width: 140, height: 30)
        content.addSubview(reveal)
        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close setup guide")!,
            target: self, action: #selector(hide))
        close.isBordered = false
        close.frame = NSRect(x: 466, y: 155, width: 18, height: 18)
        content.addSubview(close)
        self.panel = panel
        panel.center()
        panel.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.updatePosition() }
        updatePosition()
    }

    private func updatePosition() {
        guard !AXIsProcessTrusted(), let panel else { hide(); return }
        let settings = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        guard let window = windows.first(where: {
            $0[kCGWindowOwnerPID as String] as? pid_t == settings?.processIdentifier
                && $0[kCGWindowLayer as String] as? Int == 0
        }), let dictionary = window[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
              let primary = NSScreen.screens.first else {
            if sawSettings { hide() }
            return
        }
        sawSettings = true
        let frame = NSRect(x: bounds.minX, y: primary.frame.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? primary
        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let x = max(visible.minX, min(frame.maxX - panel.frame.width, visible.maxX - panel.frame.width))
        let below = frame.minY - panel.frame.height - 8
        let y = below >= visible.minY ? below : max(visible.minY, frame.minY + 12)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
