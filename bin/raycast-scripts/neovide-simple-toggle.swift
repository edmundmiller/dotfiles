#!/usr/bin/swift

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Toggle Neovide Simple
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 📝
// @raycast.packageName Neovide
// @raycast.author Edmund Miller
// @raycast.authorURL https://github.com/edmundmiller
// @raycast.description Simple toggle for Neovide - if frontmost hide it, otherwise show it

import AppKit

// Get Neovide app
let runningApps = NSWorkspace.shared.runningApplications
if let neovideApp = runningApps.first(where: { $0.bundleIdentifier == "com.neovide.neovide" }) {
    // Neovide is running
    let frontmostApp = NSWorkspace.shared.frontmostApplication
    
    if frontmostApp?.bundleIdentifier == "com.neovide.neovide" {
        // Neovide is frontmost, hide it
        neovideApp.hide()
        print("Hidden Neovide")
    } else {
        // Neovide not frontmost, bring to front
        neovideApp.activate(options: .activateAllWindows)
        print("Activated Neovide")
    }
} else {
    // Neovide not running, launch it
    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Neovide.app"))
    print("Launched Neovide")
}