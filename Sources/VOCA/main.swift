import AppKit
import SwiftUI
import VOCACore

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // .regular so VOCA is visible in the Dock and Cmd+Tab — the user
    // can always re-find the dashboard window. The menu-bar item is still
    // the primary control surface; the Dock icon is just discoverability.
    app.setActivationPolicy(.regular)
    app.run()
}
