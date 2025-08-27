#!/usr/bin/swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Toggle Neovide
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 📝
// @raycast.packageName Neovide
// @raycast.author Edmund Miller
// @raycast.authorURL https://github.com/edmundmiller
// @raycast.description Toggle Neovide - if hidden show it, if visible hide it, if not running start it

import AppKit
import Cocoa

// Function to get the Neovide application
func getNeovideApp() -> NSRunningApplication? {
    let runningApps = NSWorkspace.shared.runningApplications
    return runningApps.first { $0.bundleIdentifier == "com.neovide.neovide" }
}

// Function to check if app has windows
func hasWindows(_ app: NSRunningApplication) -> Bool {
    // Use AppleScript to check window count since we can't directly access windows
    let script = """
    tell application "Neovide"
        return count of windows
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        if error == nil {
            return result.int32Value > 0
        }
    }
    return false
}

// Function to create a new window
func createNewWindow() {
    let script = """
    tell application "Neovide" 
        activate
    end tell
    tell application "System Events"
        keystroke "n" using {command down, shift down}
    end tell
    """
    
    if let scriptObject = NSAppleScript(source: script) {
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
    }
}

// Main logic
if let neovideApp = getNeovideApp() {
    // Neovide is running
    
    // Check if Neovide is the frontmost app
    let frontmostApp = NSWorkspace.shared.frontmostApplication
    let isFrontmost = frontmostApp?.bundleIdentifier == "com.neovide.neovide"
    
    if !hasWindows(neovideApp) {
        // No windows, create new window
        createNewWindow()
        print("Created new Neovide window")
    } else if isFrontmost {
        // Neovide is frontmost, hide it
        neovideApp.hide()
        print("Hidden Neovide")
    } else {
        // Neovide is running but not frontmost, activate it
        neovideApp.activate(options: [])
        print("Brought Neovide to front")
    }
} else {
    // Neovide not running, launch it
    let workspace = NSWorkspace.shared
    let url = URL(fileURLWithPath: "/Applications/Neovide.app")
    
    workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
        if let error = error {
            print("Failed to launch Neovide: \(error)")
        } else {
            print("Launched Neovide")
        }
    }
    
    // Need to keep the script alive briefly for async callback
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
}