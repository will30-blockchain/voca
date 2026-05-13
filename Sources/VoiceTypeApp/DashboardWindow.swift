import AppKit
import SwiftUI
import VoiceTypeCore

@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    private let engine: VoiceTypeEngine
    private let settingsStore: SettingsStore
    private let memory: PersonalMemory
    private let history: TranscriptHistory
    private let openSettings: () -> Void
    private let openProviders: () -> Void
    private let openDictionary: () -> Void
    private let openMemory: () -> Void

    private var window: NSWindow?

    init(
        engine: VoiceTypeEngine,
        settingsStore: SettingsStore,
        memory: PersonalMemory,
        history: TranscriptHistory,
        openSettings: @escaping () -> Void,
        openProviders: @escaping () -> Void,
        openDictionary: @escaping () -> Void,
        openMemory: @escaping () -> Void
    ) {
        self.engine = engine
        self.settingsStore = settingsStore
        self.memory = memory
        self.history = history
        self.openSettings = openSettings
        self.openProviders = openProviders
        self.openDictionary = openDictionary
        self.openMemory = openMemory
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = DashboardView(
            openSettings: openSettings,
            openProviders: openProviders,
            openDictionary: openDictionary,
            openMemory: openMemory
        )
        .environmentObject(engine)
        .environmentObject(settingsStore)
        .environmentObject(memory)
        .environmentObject(history)

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "VoiceType"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 760, height: 560))
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
