// Opt-in GUI test target. Never bundled with TinyType or launched by normal tests.
import AppKit
import WebKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 700, height: 500),
    styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.title = "TinyType disposable input fixture"
let native = NSTextView(frame: NSRect(x: 20, y: 300, width: 650, height: 150))
native.isAutomaticSpellingCorrectionEnabled = false
let web = WKWebView(frame: NSRect(x: 20, y: 10, width: 650, height: 260))
window.contentView!.addSubview(native)
window.contentView!.addSubview(web)
web.loadHTMLString("""
    <textarea id="area" spellcheck="false"></textarea>
    <input id="single" spellcheck="false">
    <div id="rich" contenteditable="true" spellcheck="false"></div>
    <input id="readonly" readonly value="leave me alone">
    <input id="password" type="password">
    <script>let inputEvents = 0; document.addEventListener('input', () => inputEvents++);</script>
    """, baseURL: nil)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

func reply(_ value: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: value)
    FileHandle.standardOutput.write(data + Data([10]))
}

DispatchQueue.global().async {
    while let line = readLine(), let data = line.data(using: .utf8),
          let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        DispatchQueue.main.async {
            switch command["op"] as? String {
            case "native":
                native.string = command["text"] as? String ?? ""
                window.makeFirstResponder(native)
                native.setSelectedRange(NSRange(location: command["caret"] as? Int ?? native.string.utf16.count,
                    length: command["length"] as? Int ?? 0))
                app.activate(ignoringOtherApps: true)
                reply(["ok": true])
            case "value": reply(["text": native.string, "caret": native.selectedRange().location])
            case "feedback":
                let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
                let owned = windows.filter {
                    $0[kCGWindowOwnerPID as String] as? Int == command["pid"] as? Int
                        && ($0[kCGWindowAlpha as String] as? Double ?? 0) > 0
                }
                reply(["windows": owned, "frontmost": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0])
            case "js":
                web.evaluateJavaScript(command["script"] as! String) { value, error in
                    reply(["value": value ?? NSNull(), "error": error?.localizedDescription ?? ""])
                }
            default: reply(["error": "unknown_operation"])
            }
        }
    }
    exit(0)
}
app.run()
