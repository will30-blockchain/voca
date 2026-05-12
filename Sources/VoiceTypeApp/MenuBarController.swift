import AppKit
import Combine
import VoiceTypeCore

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let engine: VoiceTypeEngine
    private var cancellables: Set<AnyCancellable> = []

    private let openSettings: () -> Void
    private let openMemory: () -> Void
    private let openDictionary: () -> Void

    init(
        engine: VoiceTypeEngine,
        openSettings: @escaping () -> Void,
        openMemory: @escaping () -> Void,
        openDictionary: @escaping () -> Void
    ) {
        self.engine = engine
        self.openSettings = openSettings
        self.openMemory = openMemory
        self.openDictionary = openDictionary
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
        rebuildMenu(state: engine.state)

        engine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handle(state: state)
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = symbol(for: .idle)
        button.imagePosition = .imageOnly
        button.toolTip = "VoiceType — Right Option to dictate · Right Option + Right Shift to translate"
    }

    private func handle(state: EngineState) {
        guard let button = statusItem.button else { return }
        button.image = symbol(for: state)
        rebuildMenu(state: state)
    }

    private func symbol(for state: EngineState) -> NSImage? {
        let name: String
        switch state {
        case .idle: name = "waveform"
        case .recording: name = "mic.circle.fill"
        case .processing: name = "ellipsis.circle.fill"
        case .error: name = "exclamationmark.triangle.fill"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "VoiceType") ?? NSImage()
        img.isTemplate = true
        return img
    }

    private func rebuildMenu(state: EngineState) {
        let menu = NSMenu()

        let header = NSMenuItem(title: title(for: state), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let dict = NSMenuItem(title: "Dictionary…", action: #selector(handleDictionary), keyEquivalent: "")
        dict.target = self
        menu.addItem(dict)

        let memory = NSMenuItem(title: "Personal memory…", action: #selector(handleMemory), keyEquivalent: "")
        memory.target = self
        menu.addItem(memory)

        let settings = NSMenuItem(title: "Settings…", action: #selector(handleSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About VoiceType", action: #selector(handleAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit VoiceType", action: #selector(handleQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func title(for state: EngineState) -> String {
        switch state {
        case .idle: return "VoiceType — ready"
        case .recording(let mode): return mode == .translate ? "Translating…" : "Listening…"
        case .processing(_, let stage): return stage
        case .error(let m): return "Error: \(m)"
        }
    }

    @objc private func handleSettings() { openSettings() }
    @objc private func handleMemory() { openMemory() }
    @objc private func handleDictionary() { openDictionary() }
    @objc private func handleQuit() { NSApp.terminate(nil) }
    @objc private func handleAbout() {
        let alert = NSAlert()
        alert.messageText = "VoiceType"
        alert.informativeText = "Dictation and translation that runs on your own API keys.\n\nRight Option — dictate.\nRight Option + Right Shift — translate.\n\nGlossary and personal memory live in ~/Library/Application Support/VoiceType."
        alert.runModal()
    }
}
