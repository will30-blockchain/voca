import AppKit
import SwiftUI
import VoiceTypeCore

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, providers, languages, dictionary, memory, logs, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .languages: return "Languages"
        case .dictionary: return "Dictionary"
        case .memory: return "Memory"
        case .logs: return "Logs"
        case .about: return "About"
        }
    }
    var systemImage: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .providers: return "key.fill"
        case .languages: return "globe"
        case .dictionary: return "character.book.closed"
        case .memory: return "brain"
        case .logs: return "text.alignleft"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settingsStore: SettingsStore
    private let memory: PersonalMemory
    private let dictionary: UserDictionary
    private let log: LogStore
    private var window: NSWindow?

    init(settingsStore: SettingsStore, memory: PersonalMemory, dictionary: UserDictionary, log: LogStore) {
        self.settingsStore = settingsStore
        self.memory = memory
        self.dictionary = dictionary
        self.log = log
    }

    func show(tab: SettingsTab) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let root = SettingsView(initialTab: tab)
            .environmentObject(settingsStore)
            .environmentObject(memory)
            .environmentObject(dictionary)
            .environmentObject(log)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "VoiceType Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 720, height: 480)
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
