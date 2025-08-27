#!/usr/bin/swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Neovide Quake Pro
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🚀
// @raycast.packageName Neovide
// @raycast.author Edmund Miller
// @raycast.authorURL https://github.com/edmundmiller
// @raycast.description Ultimate Quake terminal - smooth animations, transparency, always-on-top

import AppKit
import Cocoa
import CoreGraphics
import QuartzCore

// Pro Quake Configuration
struct QuakeConfig {
    static let heightPercent: CGFloat = 0.55    // Sweet spot for Quake feel
    static let animationDuration: Double = 0.18  // Fast like original Quake
    static let animationSteps: Int = 15         // Smooth animation
    static let transparency: CGFloat = 0.92     // Slight transparency
    static let shadowEnabled = true            // Drop shadow
    static let blurBackground = false          // Don't blur (performance)
    static let stealFocus = true               // Always grab focus
    static let hideFromDock = true             // Act like overlay
    static let debug = true                    // Enable debug output
}

class QuakeController {
    private let stateFile = "/tmp/neovide-quake-pro-state"
    private let quakeNeovideTitle = "Neovide-Quake"
    private var isAnimating = false
    private var quakeNeovideProcess: Process?
    
    enum State: String {
        case hidden = "hidden"
        case visible = "visible" 
        case animating = "animating"
    }
    
    // MARK: - State Management
    
    private func saveState(_ state: State) {
        try? state.rawValue.write(toFile: stateFile, atomically: true, encoding: .utf8)
    }
    
    private func readState() -> State {
        guard let content = try? String(contentsOfFile: stateFile, encoding: .utf8) else { return .hidden }
        return State(rawValue: content) ?? .hidden
    }
    
    // MARK: - Window Detection
    
    private func isQuakeNeovideRunning() -> Bool {
        let script = """
        tell application "System Events"
            try
                set windowList to every window of process "Neovide" whose name contains "\(quakeNeovideTitle)"
                return (count of windowList) > 0
            on error
                return false
            end try
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = scriptObject.executeAndReturnError(&error)
            if let boolResult = result.booleanValue {
                return boolResult
            }
        }
        return false
    }
    
    private func isQuakeNeovideActive() -> Bool {
        let script = """
        tell application "System Events"
            try
                set frontWindow to window 1 of (first application process whose frontmost is true)
                set windowName to name of frontWindow
                return windowName contains "\(quakeNeovideTitle)"
            on error
                return false
            end try
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = scriptObject.executeAndReturnError(&error)
            if let boolResult = result.booleanValue {
                debugLog("Quake Neovide active: \(boolResult)")
                return boolResult
            }
        }
        debugLog("Quake Neovide active: false")
        return false
    }
    
    private func debugLog(_ message: String) {
        if QuakeConfig.debug { print("🔍 Debug: \(message)") }
    }
    
    // MARK: - Quake Neovide Management
    
    private func launchQuakeNeovide() {
        let process = Process()
        process.launchPath = "/Applications/Neovide.app/Contents/MacOS/neovide"
        
        // Set a custom title for the Quake instance
        process.arguments = [
            "--title-hidden",
            "--title", quakeNeovideTitle,
            "+set titlestring=\(quakeNeovideTitle)"
        ]
        
        // Set environment to distinguish this instance
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["NEOVIDE_QUAKE_MODE"] = "true"
        
        do {
            try process.run()
            quakeNeovideProcess = process
            debugLog("Launched Quake Neovide with PID: \(process.processIdentifier)")
        } catch {
            debugLog("Failed to launch Quake Neovide: \(error)")
            // Fallback to regular app launch
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Neovide.app"))
        }
    }
    
    private func activateQuakeNeovide() {
        let script = """
        tell application "System Events"
            tell process "Neovide"
                set quakeWindows to (every window whose name contains "\(quakeNeovideTitle)")
                if (count of quakeWindows) > 0 then
                    tell item 1 of quakeWindows
                        set frontmost to true
                        set visible to true
                    end tell
                end if
            end tell
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                debugLog("Activation error: \(error)")
            }
        }
    }
    
    // MARK: - Animation Engine
    
    private func animateWindow(from startY: Int, to endY: Int, completion: @escaping () -> Void) {
        guard !isAnimating else { return }
        isAnimating = true
        saveState(.animating)
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let stepDuration = QuakeConfig.animationDuration / Double(QuakeConfig.animationSteps)
            
            for i in 0...QuakeConfig.animationSteps {
                let progress = Double(i) / Double(QuakeConfig.animationSteps)
                // Use easing function for smoother animation
                let easedProgress = self?.easeOutQuart(progress) ?? progress
                
                let currentY = Double(startY) + (Double(endY - startY) * easedProgress)
                
                let script = """
                tell application "System Events"
                    tell process "Neovide"
                        set quakeWindows to (every window whose name contains "\(self?.quakeNeovideTitle ?? "")")
                        if (count of quakeWindows) > 0 then
                            tell item 1 of quakeWindows
                                set position to {0, \(Int(currentY))}
                            end tell
                        end if
                    end tell
                end tell
                """
                
                DispatchQueue.main.sync {
                    if let scriptObject = NSAppleScript(source: script) {
                        var error: NSDictionary?
                        scriptObject.executeAndReturnError(&error)
                    }
                }
                
                if i < QuakeConfig.animationSteps {
                    Thread.sleep(forTimeInterval: stepDuration)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.isAnimating = false
                completion()
            }
        }
    }
    
    private func easeOutQuart(_ t: Double) -> Double {
        return 1 - pow(1 - t, 4)
    }
    
    // MARK: - Window Management
    
    private func setupQuakeWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let windowWidth = Int(screenFrame.width)
        let windowHeight = Int(screenFrame.height * QuakeConfig.heightPercent)
        
        debugLog("Setting up Quake window: \(windowWidth)x\(windowHeight)")
        
        // Enhanced window setup targeting the Quake-specific Neovide window
        let script = """
        tell application "System Events"
            tell process "Neovide"
                set frontmost to true
                
                -- Find the Quake Neovide window specifically
                set quakeWindows to (every window whose name contains "\(quakeNeovideTitle)")
                if (count of quakeWindows) > 0 then
                    tell item 1 of quakeWindows
                        -- Set size and position
                        set size to {\(windowWidth), \(windowHeight)}
                        set position to {0, 0}
                        
                        -- Multiple attempts to remove window decorations
                        try
                            set subrole to "floating"
                        end try
                        
                        try
                            set value of attribute "AXTitleUIElement" to false
                        end try
                        
                        try
                            set value of attribute "AXDecorated" to false
                        end try
                        
                        try
                            set value of attribute "AXHasCloseButton" to false
                        end try
                        
                        try
                            set value of attribute "AXHasMinimizeButton" to false
                        end try
                        
                        try
                            set value of attribute "AXHasZoomButton" to false
                        end try
                        
                        try
                            set value of attribute "AXHasTitleBar" to false
                        end try
                        
                        -- Ensure proper window state
                        set miniaturized to false
                        set zoomed to false
                    end tell
                end if
            end tell
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                debugLog("AppleScript error: \(error)")
            }
        }
    }
    
    // MARK: - Quake Actions
    
    func dropDown() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Launch or activate separate Quake Neovide instance
        if !isQuakeNeovideRunning() {
            debugLog("Launching new Quake Neovide instance")
            launchQuakeNeovide()
            Thread.sleep(forTimeInterval: 2.0)  // Wait for launch
        } else {
            debugLog("Activating existing Quake Neovide")
            activateQuakeNeovide()
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        setupQuakeWindow()
        Thread.sleep(forTimeInterval: 0.1)
        
        // Animate drop down from above screen
        let windowHeight = Int(screenFrame.height * QuakeConfig.heightPercent)
        let startY = -windowHeight  // Start hidden above screen
        let endY = 25               // End at top of screen
        
        animateWindow(from: startY, to: endY) { [weak self] in
            self?.saveState(.visible)
            self?.debugLog("Animation completed - terminal deployed")
            print("🎮 Quake mode: Terminal deployed!")
        }
    }
    
    func slideUp() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let windowHeight = Int(screenFrame.height * QuakeConfig.heightPercent)
        let startY = 25             // Current position
        let endY = -windowHeight    // Hide above screen
        
        animateWindow(from: startY, to: endY) { [weak self] in
            // Hide only the Quake window
            let hideScript = """
            tell application "System Events"
                tell process "Neovide"
                    set quakeWindows to (every window whose name contains "\(self?.quakeNeovideTitle ?? "")")
                    if (count of quakeWindows) > 0 then
                        tell item 1 of quakeWindows
                            set visible to false
                        end tell
                    end if
                end tell
            end tell
            """
            
            if let scriptObject = NSAppleScript(source: hideScript) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
            }
            
            self?.saveState(.hidden)
            print("🎮 Quake mode: Terminal retracted!")
        }
    }
    
    // MARK: - Main Toggle Logic
    
    func toggle() {
        let currentState = readState()
        
        // Don't allow multiple animations
        if currentState == .animating { return }
        
        if !isQuakeNeovideRunning() {
            // Launch separate Quake Neovide instance
            debugLog("Launching new Quake Neovide instance")
            launchQuakeNeovide()
            
            // Wait for launch and then drop down
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.dropDown()
            }
        } else {
            // Toggle based on current state
            if isQuakeNeovideActive() && currentState == .visible {
                slideUp()
            } else {
                dropDown()
            }
        }
    }
    
    deinit {
        // Clean up process if needed
        quakeNeovideProcess?.terminate()
    }
}

// Execute
let controller = QuakeController()
controller.toggle()