#!/usr/bin/swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Neovide Quake Mode
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🚀
// @raycast.packageName Neovide
// @raycast.author Edmund Miller
// @raycast.authorURL https://github.com/edmundmiller
// @raycast.description Toggle Neovide as a Quake-style dropdown terminal from the top of the screen

import AppKit
import Cocoa

// Configuration
let QUAKE_HEIGHT_PERCENTAGE: CGFloat = 0.5  // 50% of screen height
let ANIMATION_DURATION: TimeInterval = 0.2

// Function to position window in Quake mode
func positionWindowQuakeStyle() {
    // Get main screen dimensions
    guard let screen = NSScreen.main else { return }
    let screenFrame = screen.frame
    
    // Calculate Quake window dimensions
    let windowWidth = screenFrame.width
    let windowHeight = screenFrame.height * QUAKE_HEIGHT_PERCENTAGE
    let windowX: CGFloat = 0
    let windowY = screenFrame.height - windowHeight  // macOS coordinates start from bottom-left
    
    // Use AppleScript to position the window
    let script = """
    tell application "System Events"
        tell process "Neovide"
            set frontmost to true
            tell window 1
                set position to {\(Int(windowX)), \(Int(screenFrame.height - windowY - windowHeight))}
                set size to {\(Int(windowWidth)), \(Int(windowHeight))}
            end tell
        end tell
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if let error = error {
            print("Error positioning window: \(error)")
        }
    }
}

// Function to check if Neovide window is visible
func isNeovideVisible() -> Bool {
    let script = """
    tell application "System Events"
        if exists process "Neovide" then
            tell process "Neovide"
                if (count of windows) > 0 then
                    return visible of window 1
                else
                    return false
                end if
            end tell
        else
            return false
        end if
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        if error == nil {
            return result.booleanValue
        }
    }
    return false
}

// Function to show Neovide window
func showNeovide() {
    let script = """
    tell application "Neovide"
        activate
        reopen
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
    }
    
    // Small delay to ensure window is ready
    Thread.sleep(forTimeInterval: 0.1)
    
    // Position in Quake style
    positionWindowQuakeStyle()
}

// Function to hide Neovide window
func hideNeovide() {
    let script = """
    tell application "System Events"
        tell process "Neovide"
            set visible to false
        end tell
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
    }
}

// Main logic
let runningApps = NSWorkspace.shared.runningApplications
if runningApps.contains(where: { $0.bundleIdentifier == "com.neovide.neovide" }) {
    // Neovide is running
    let frontmostApp = NSWorkspace.shared.frontmostApplication
    let isFrontmost = frontmostApp?.bundleIdentifier == "com.neovide.neovide"
    
    if isFrontmost && isNeovideVisible() {
        // Neovide is frontmost and visible, hide it (slide up animation effect)
        hideNeovide()
        print("Neovide hidden (slid up)")
    } else {
        // Show and position Neovide in Quake mode
        showNeovide()
        print("Neovide shown in Quake mode")
    }
} else {
    // Neovide not running, launch it
    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Neovide.app"))
    
    // Wait for it to launch
    Thread.sleep(forTimeInterval: 1.0)
    
    // Position in Quake style
    positionWindowQuakeStyle()
    print("Launched Neovide in Quake mode")
}