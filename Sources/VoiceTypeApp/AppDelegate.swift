import AppKit
import SwiftUI
import VoiceTypeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let memory = PersonalMemory()
    let dictionary = UserDictionary()
    let recorder = AudioRecorder()
    let injector = TextInjector()
    let hotkeys = HotkeyManager()
    lazy var engine = VoiceTypeEngine(
        settingsStore: settingsStore,
        memory: memory,
        dictionary: dictionary,
        recorder: recorder,
        injector: injector
    )

    private var menuBar: MenuBarController?
    private var hudController: HUDWindowController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("VoiceType launched.")

        // Request mic + accessibility ASAP so the user only sees the system
        // prompts once, not on the first dictation press.
        Task { _ = await Permissions.requestMicrophone() }
        _ = Permissions.requestAccessibility(prompt: true)

        menuBar = MenuBarController(
            engine: engine,
            openSettings: { [weak self] in self?.showSettings() },
            openMemory: { [weak self] in self?.showSettings(tab: .memory) },
            openDictionary: { [weak self] in self?.showSettings(tab: .dictionary) }
        )

        hudController = HUDWindowController(engine: engine, settingsStore: settingsStore)

        // Wire hotkeys → engine.
        hotkeys.onBegin = { [weak self] mode in
            Task { await self?.engine.beginRecording(mode: mode) }
        }
        hotkeys.onEnd = { [weak self] _ in
            Task { await self?.engine.endRecording() }
        }
        hotkeys.onCancel = { [weak self] in
            Task { await self?.engine.cancelRecording() }
        }
        hotkeys.start()

        // First-run cue.
        if !UserDefaults.standard.bool(forKey: "vt.didFirstRun") {
            UserDefaults.standard.set(true, forKey: "vt.didFirstRun")
            showSettings(tab: .providers)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
    }

    // MARK: - Windows

    func showSettings(tab: SettingsTab = .general) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                settingsStore: settingsStore,
                memory: memory,
                dictionary: dictionary
            )
        }
        settingsWindowController?.show(tab: tab)
    }
}
