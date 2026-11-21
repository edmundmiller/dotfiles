import AppKit
import ApplicationServices
import Carbon
import Foundation

private let maximumTextUnits = 16_384

private struct HelperRequest: Decodable {
    let op: String
    let token: UInt64?
    let text: String?
    let caret: Int?
    let from: Int?
    let to: Int?
    let original: String?
    let replacement: String?
}

private struct FocusedTextError: Error {
    let reason: String
    init(_ reason: String) { self.reason = reason }
}

private struct FocusedTextState {
    let element: AXUIElement
    let pid: pid_t
    let bundle: String
    let text: String
    let selection: CFRange
}

private struct RetainedSnapshot {
    let token: UInt64
    let state: FocusedTextState
}

private struct FocusedTextUndo {
    let state: FocusedTextState
    let from: Int
    let replacement: String
    let original: String
    let originalCaret: Int
}

private func sameRange(_ lhs: CFRange, _ rhs: CFRange) -> Bool {
    lhs.location == rhs.location && lhs.length == rhs.length
}

// Swift String equality normalizes Unicode; document validation must compare exact UTF-16 units.
private func sameText(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf16.elementsEqual(rhs.utf16)
}

private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

private func selectedRange(_ element: AXUIElement) -> CFRange? {
    guard let value = attribute(element, kAXSelectedTextRangeAttribute),
          CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cfRange else { return nil }
    var range = CFRange()
    guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
    return range
}

private func setSelectedRange(_ element: AXUIElement, _ range: CFRange) -> Bool {
    var range = range
    guard let value = AXValueCreate(.cfRange, &range) else { return false }
    guard AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success else { return false }
    let deadline = Date().addingTimeInterval(0.2)
    repeat {
        if let current = selectedRange(element), sameRange(current, range) { return true }
        Thread.sleep(forTimeInterval: 0.01)
    } while Date() < deadline
    return false
}

private func isSettable(_ element: AXUIElement, _ name: String) -> Bool {
    var settable = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success && settable.boolValue
}

private func isUTF16Boundary(_ offset: Int, in text: String) -> Bool {
    let units = Array(text.utf16)
    guard offset >= 0 && offset <= units.count else { return false }
    if offset == 0 || offset == units.count { return true }
    return !(0xD800...0xDBFF).contains(units[offset - 1]) || !(0xDC00...0xDFFF).contains(units[offset])
}

private func replacingSpan(_ text: String, _ range: CFRange, with replacement: String) -> String {
    (text as NSString).replacingCharacters(in: NSRange(location: range.location, length: range.length), with: replacement)
}

// Resolve layer colors again when macOS changes appearance while the chip is visible.
private final class CorrectionFeedbackBackground: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let increasedContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer?.borderColor = (increasedContrast ? NSColor.labelColor : NSColor.separatorColor).cgColor
            layer?.borderWidth = increasedContrast ? 2 : 1
        }
    }
}

// Correction feedback belongs beside the verified native edit, not the settings
// window. This panel never activates, takes keyboard focus, or intercepts clicks.
private final class CorrectionFeedback {
    private var panel: NSPanel?
    private var dismissal: Timer?

    func hide() {
        dismissal?.invalidate()
        dismissal = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func wordBounds(_ element: AXUIElement, range: CFRange) -> NSRect? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter, &value) == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let boundsValue = value as! AXValue
        var bounds = CGRect.zero
        guard AXValueGetType(boundsValue) == .cgRect, AXValueGetValue(boundsValue, .cgRect, &bounds),
              !bounds.isNull, !bounds.isInfinite, bounds.height > 0,
              let primary = NSScreen.screens.first else { return nil }
        // AX uses a top-left primary-display origin; AppKit uses bottom-left.
        return NSRect(x: bounds.minX, y: primary.frame.maxY - bounds.maxY,
            width: bounds.width, height: bounds.height)
    }

    func show(_ state: FocusedTextState, from: Int, original: String, replacement: String, undone: Bool = false) {
        hide()
        let bounds = wordBounds(state.element, range: CFRange(location: from, length: replacement.utf16.count))
            ?? wordBounds(state.element, range: state.selection)
        let anchor = bounds.map { NSPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)

        let label = NSTextField(labelWithString: "")
        let text = NSMutableAttributedString(string: "TinyType  ", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        text.append(NSAttributedString(string: "\(original) → ", attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        text.append(NSAttributedString(string: replacement, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]))
        text.append(NSAttributedString(string: undone ? "   Undone" : "   ⌥⌘Z", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        label.attributedStringValue = text
        label.sizeToFit()
        let size = NSSize(width: min(label.frame.width + 28, visible.width), height: 34)
        var origin = NSPoint(x: bounds?.minX ?? visible.midX - size.width / 2,
            y: bounds.map { $0.minY - size.height - 7 } ?? visible.minY + 24)
        if let bounds, origin.y < visible.minY { origin.y = bounds.maxY + 7 }
        origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
        origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        let view = CorrectionFeedbackBackground(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        label.frame = NSRect(x: 14, y: (size.height - label.frame.height) / 2,
            width: size.width - 28, height: label.frame.height)
        view.addSubview(label)
        panel.contentView = view
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        self.panel = panel
        panel.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
        dismissal = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self, weak panel] _ in
            guard let self, let panel, self.panel === panel else { return }
            if reduceMotion { self.hide(); return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                guard let self, let panel, self.panel === panel else { return }
                self.hide()
            })
        }
    }
}

private final class FocusedTextHelper {
    private var snapshot: RetainedSnapshot?
    private var undo: FocusedTextUndo?
    private let feedback = CorrectionFeedback()
    private let accessibilityGuide = AccessibilityGuide()
    private var nextToken: UInt64 = 1
    private var focusObserver: AXObserver?
    private var observedPID: pid_t?
    private var activationObserver: NSObjectProtocol?
    private var activatedPID: pid_t?
    private var activationRestore: (AXUIElement, String, Bool)?

    init() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.focusChanged() }
    }

    fileprivate func focusChanged() {
        snapshot = nil
        feedback.hide()
    }

    private func releaseActivation() {
        if let (application, name, previous) = activationRestore,
           attribute(application, name) as? Bool == true {
            AXUIElementSetAttributeValue(application, name as CFString, previous ? kCFBooleanTrue : kCFBooleanFalse)
        }
        activationRestore = nil
        activatedPID = nil
    }

    func clear() {
        snapshot = nil
        undo = nil
        feedback.hide()
        releaseActivation()
    }

    private func activateAccessibility(_ application: AXUIElement, pid: pid_t) {
        guard activatedPID != pid else { return }
        releaseActivation()
        activatedPID = pid
        // Chromium and Electron can hide their text tree until an AX client asks
        // for it. Unsupported attributes are normal on native macOS controls.
        for name in ["AXEnhancedUserInterface", "AXManualAccessibility"] {
            let previous = attribute(application, name) as? Bool
            if previous == true { return }
            if AXUIElementSetAttributeValue(application, name as CFString, kCFBooleanTrue) == .success {
                if let previous { activationRestore = (application, name, previous) }
                return
            }
        }
    }

    private func observeFocus(_ pid: pid_t, application: AXUIElement) {
        guard observedPID != pid else { return }
        if let observer = focusObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observedPID = nil
        focusObserver = nil
        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            Unmanaged<FocusedTextHelper>.fromOpaque(context).takeUnretainedValue().focusChanged()
        }, &observer)
        guard result == .success, let observer,
              AXObserverAddNotification(observer, application, kAXFocusedUIElementChangedNotification as CFString,
                  Unmanaged.passUnretained(self).toOpaque()) == .success else { return }
        focusObserver = observer
        observedPID = pid
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    // Secure input and our own playground are excluded before reading any text.
    private func frontmostApplication() throws -> NSRunningApplication {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier, bundle != "dev.edmundmiller.tinytype" else {
            throw FocusedTextError("application_excluded")
        }
        guard AXIsProcessTrusted() else { throw FocusedTextError("accessibility_not_trusted") }
        guard !IsSecureEventInputEnabled() else { throw FocusedTextError("secure_event_input") }
        return app
    }

    private func readFocusedText() throws -> FocusedTextState {
        let app = try frontmostApplication()
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.25)
        activateAccessibility(application, pid: app.processIdentifier)
        observeFocus(app.processIdentifier, application: application)
        guard let value = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw FocusedTextError("no_focused_element")
        }
        let element = value as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.25)
        var elementPID: pid_t = 0
        guard AXUIElementGetPid(element, &elementPID) == .success,
              elementPID == app.processIdentifier else { throw FocusedTextError("focused_process_changed") }

        // Some applications put the secure subrole on a field's ancestor.
        var ancestor: AXUIElement? = element
        for _ in 0..<16 {
            guard let current = ancestor else { break }
            AXUIElementSetMessagingTimeout(current, 0.25)
            if attribute(current, kAXRoleAttribute) as? String == "AXSecureTextField"
                || attribute(current, kAXSubroleAttribute) as? String == "AXSecureTextField"
                || attribute(current, "AXProtectedContent") as? Bool == true {
                throw FocusedTextError("secure_text_field")
            }
            if let parent = attribute(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() {
                ancestor = (parent as! AXUIElement)
            } else { ancestor = nil }
        }
        guard let role = attribute(element, kAXRoleAttribute) as? String,
              role == kAXTextAreaRole || role == kAXTextFieldRole || role == kAXComboBoxRole else {
            throw FocusedTextError("unsupported_text_role")
        }
        guard attribute(element, kAXEnabledAttribute) as? Bool != false,
              attribute(element, "AXEditable") as? Bool != false else {
            throw FocusedTextError("text_not_editable")
        }
        guard isSettable(element, kAXSelectedTextRangeAttribute),
              isSettable(element, kAXValueAttribute) || isSettable(element, kAXSelectedTextAttribute) else {
            throw FocusedTextError("text_not_editable")
        }
        if let marked = attribute(element, "AXMarkedTextRange"), CFGetTypeID(marked) == AXValueGetTypeID() {
            let markedValue = marked as! AXValue
            var range = CFRange()
            if AXValueGetType(markedValue) == .cfRange,
               AXValueGetValue(markedValue, .cfRange, &range), range.length > 0 {
                throw FocusedTextError("marked_text")
            }
        }
        if let marked = attribute(element, "AXMarkedText") as? String, !marked.isEmpty {
            throw FocusedTextError("marked_text")
        }
        if attribute(element, "AXHasMarkedText") as? Bool == true { throw FocusedTextError("marked_text") }
        if let count = attribute(element, kAXNumberOfCharactersAttribute) as? Int, count > maximumTextUnits {
            throw FocusedTextError("text_too_long")
        }
        guard try frontmostApplication().processIdentifier == app.processIdentifier else {
            throw FocusedTextError("focused_process_changed")
        }
        guard let text = attribute(element, kAXValueAttribute) as? String else {
            throw FocusedTextError("text_unavailable")
        }
        guard text.utf16.count <= maximumTextUnits else { throw FocusedTextError("text_too_long") }
        guard let selection = selectedRange(element), selection.location >= 0, selection.length >= 0,
              selection.location <= text.utf16.count,
              selection.length <= text.utf16.count - selection.location,
              isUTF16Boundary(selection.location, in: text),
              isUTF16Boundary(selection.location + selection.length, in: text) else {
            throw FocusedTextError("selection_unavailable")
        }
        let finalApp = try frontmostApplication()
        guard finalApp.processIdentifier == app.processIdentifier else { throw FocusedTextError("focused_process_changed") }
        guard let finalFocus = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(finalFocus) == AXUIElementGetTypeID(), CFEqual(finalFocus, element) else {
            throw FocusedTextError("focused_element_changed")
        }
        return FocusedTextState(element: element, pid: app.processIdentifier,
            bundle: app.bundleIdentifier!, text: text, selection: selection)
    }

    private func validateState(_ expected: FocusedTextState, text: String, selection: CFRange) throws -> FocusedTextState {
        let current = try readFocusedText()
        guard current.pid == expected.pid, CFEqual(current.element, expected.element) else {
            throw FocusedTextError("focused_element_changed")
        }
        guard sameText(current.text, text) else { throw FocusedTextError("text_changed") }
        guard sameRange(current.selection, selection) else { throw FocusedTextError("selection_changed") }
        return current
    }

    // Native typing commits browser/Electron editor state, where AX setters can
    // report success without editing. Never write AXValue or use the clipboard.
    private func editSpan(_ before: FocusedTextState, range: CFRange, replacement: String, caret: Int) throws -> FocusedTextState {
        let end = range.location + range.length
        guard before.selection.length == 0, end <= before.selection.location else {
            throw FocusedTextError("replacement_not_supported")
        }
        // End the native insertion at the user's caret. Restoring it with a
        // second AX write leaves an intermediate caret that resumed typing can
        // use, and can overwrite a newer caret. Retype only this bounded tail.
        let tail = (before.text as NSString).substring(with: NSRange(location: end, length: before.selection.location - end))
        let targetRange = CFRange(location: range.location, length: before.selection.location - range.location)
        let units = Array((replacement + tail).utf16)
        // Keep a correction in one event pair. Do not split long replacements
        // into separately dispatched writes with independently racing focus.
        guard !units.isEmpty, units.count <= 20, targetRange.length <= 20,
              caret == range.location + units.count,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw FocusedTextError("replacement_not_supported")
        }
        down.flags = []
        up.flags = []
        down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        _ = try validateState(before, text: before.text, selection: before.selection)
        let afterText = replacingSpan(before.text, range, with: replacement)
        let afterSelection = CFRange(location: caret, length: 0)
        var writeAttempted = false
        do {
            guard setSelectedRange(before.element, targetRange) else { throw FocusedTextError("target_selection_failed") }
            _ = try validateState(before, text: before.text, selection: targetRange)
            writeAttempted = true
            down.postToPid(before.pid)
            up.postToPid(before.pid)
            // Delivery is asynchronous. Never resend an event if confirmation
            // times out, since the first event can still arrive later.
            let deadline = Date().addingTimeInterval(0.25)
            var edited = try readFocusedText()
            while edited.pid == before.pid, CFEqual(edited.element, before.element),
                  sameText(edited.text, before.text), Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
                edited = try readFocusedText()
            }
            guard edited.pid == before.pid, CFEqual(edited.element, before.element), sameText(edited.text, afterText),
                  sameRange(edited.selection, afterSelection) else {
                throw FocusedTextError("edit_verification_failed")
            }
            return try validateState(before, text: afterText, selection: afterSelection)
        } catch {
            if writeAttempted { throw FocusedTextError("edit_failed_text_may_have_changed") }
            // Restore the old selection only if the text and target selection still belong to this transaction.
            guard let current = try? readFocusedText(), current.pid == before.pid,
                  CFEqual(current.element, before.element) else {
                throw error
            }
            guard sameText(current.text, before.text) else {
                // A failed AX call may still have edited. Report that explicitly; do not risk a second edit.
                throw FocusedTextError("edit_failed_text_may_have_changed")
            }
            if sameRange(current.selection, targetRange) {
                if !setSelectedRange(before.element, before.selection)
                    || selectedRange(before.element).map({ sameRange($0, before.selection) }) != true {
                    throw FocusedTextError("edit_failed_selection_restore_failed")
                }
            }
            throw error
        }
    }

    private func snapshotReply() -> [String: Any] {
        do {
            let current = try readFocusedText()
            guard current.selection.length == 0 else { throw FocusedTextError("selection_not_collapsed") }
            let token: UInt64
            if let previous = snapshot, previous.state.pid == current.pid,
               CFEqual(previous.state.element, current.element) { token = previous.token }
            else { token = nextToken; nextToken += 1 }
            snapshot = RetainedSnapshot(token: token, state: current)
            return ["snapshot": ["token": token, "text": current.text, "caret": current.selection.location,
                "pid": current.pid, "bundle": current.bundle]]
        } catch {
            snapshot = nil
            return ["snapshot": NSNull(), "reason": failureReason(error)]
        }
    }

    private func replaceReply(_ request: HelperRequest) throws -> [String: Any] {
        guard let retained = snapshot, request.token == retained.token else { throw FocusedTextError("stale_token") }
        guard let text = request.text, let caret = request.caret, let from = request.from, let to = request.to,
              let original = request.original, let replacement = request.replacement,
              from >= 0, to > from, to <= text.utf16.count,
              isUTF16Boundary(from, in: text), isUTF16Boundary(to, in: text),
              isUTF16Boundary(caret, in: text) else { throw FocusedTextError("invalid_replace_request") }
        guard sameText(retained.state.text, text), retained.state.selection.location == caret,
              retained.state.selection.length == 0 else { throw FocusedTextError("snapshot_mismatch") }
        let range = CFRange(location: from, length: to - from)
        guard sameText((text as NSString).substring(with: NSRange(location: from, length: to - from)), original),
              !sameText(original, replacement) else { throw FocusedTextError("original_mismatch_or_no_change") }
        let afterText = replacingSpan(text, range, with: replacement)
        guard afterText.utf16.count <= maximumTextUnits else { throw FocusedTextError("text_too_long") }
        let adjustedCaret = caret < from ? caret : (caret >= to ? caret + replacement.utf16.count - (to - from) : from + replacement.utf16.count)
        let current = try validateState(retained.state, text: text, selection: CFRange(location: caret, length: 0))
        let after = try editSpan(current, range: range, replacement: replacement, caret: adjustedCaret)
        undo = FocusedTextUndo(state: after, from: from, replacement: replacement,
            original: original, originalCaret: caret)
        snapshot = RetainedSnapshot(token: retained.token, state: after)
        feedback.show(after, from: from, original: original, replacement: replacement)
        return ["applied": true]
    }

    private func undoReply() throws -> [String: Any] {
        guard let saved = undo else { throw FocusedTextError("no_undo") }
        let current = try validateState(saved.state, text: saved.state.text, selection: saved.state.selection)
        let range = CFRange(location: saved.from, length: saved.replacement.utf16.count)
        let after = try editSpan(current, range: range, replacement: saved.original, caret: saved.originalCaret)
        undo = nil
        if let retained = snapshot, CFEqual(retained.state.element, after.element) {
            snapshot = RetainedSnapshot(token: retained.token, state: after)
        }
        feedback.show(after, from: saved.from, original: saved.replacement, replacement: saved.original, undone: true)
        return ["applied": true, "original": saved.original]
    }

    func reply(_ request: HelperRequest) -> [String: Any] {
        do {
            switch request.op {
            case "status":
                let trusted = AXIsProcessTrusted()
                if trusted { accessibilityGuide.hide() }
                return ["trusted": trusted, "apple_autocorrect": NSSpellChecker.isAutomaticSpellingCorrectionEnabled]
            case "keyboard_settings":
                guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"),
                      NSWorkspace.shared.open(url) else { throw FocusedTextError("keyboard_settings_unavailable") }
                return [:]
            case "permission":
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                let trusted = AXIsProcessTrustedWithOptions(options)
                accessibilityGuide.show()
                return ["trusted": trusted, "list": AccessibilityGuide.listName]
            case "snapshot": return snapshotReply()
            case "replace": return try replaceReply(request)
            case "undo": return try undoReply()
            case "clear": clear(); return [:]
            default: return ["applied": false, "reason": "unsupported_operation"]
            }
        } catch { return ["applied": false, "reason": failureReason(error)] }
    }
}

private func failureReason(_ error: Error) -> String {
    (error as? FocusedTextError)?.reason ?? "internal_error"
}

// Keep the main run loop available for AX focus and application activation notifications.
// Requests remain strictly serial, and EOF exits without saving any state.
@main
private struct FocusedTextProgram {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let focusedTextHelper = FocusedTextHelper()
        DispatchQueue.global(qos: .userInitiated).async {
            while let line = readLine(strippingNewline: true) {
                DispatchQueue.main.sync {
                    autoreleasepool {
                        let reply: [String: Any]
                        if let data = line.data(using: .utf8), let request = try? JSONDecoder().decode(HelperRequest.self, from: data) {
                            reply = focusedTextHelper.reply(request)
                        } else { reply = ["applied": false, "reason": "invalid_request"] }
                        if let data = try? JSONSerialization.data(withJSONObject: reply, options: [.sortedKeys]) {
                            FileHandle.standardOutput.write(data)
                            FileHandle.standardOutput.write(Data([0x0A]))
                        }
                    }
                }
            }
            DispatchQueue.main.sync { focusedTextHelper.clear() }
            exit(0)
        }
        application.run()
    }
}
