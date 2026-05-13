import AppKit
import SwiftUI
import VoiceTypeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let memory = PersonalMemory()
    let dictionary = UserDictionary()
    let injector = TextInjector()
    let hotkeys = HotkeyManager()
    lazy var engine = VoiceTypeEngine(
        settingsStore: settingsStore,
        memory: memory,
        dictionary: dictionary,
        recorder: AudioRecorder(),
        injector: injector
    )

    private var menuBar: MenuBarController?
    private var hudController: HUDWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var dashboardController: DashboardWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("VoiceType launched.")

        // Request mic + accessibility ASAP so the user only sees the system
        // prompts once, not on the first dictation press. forceMicrophone…
        // opens a tiny capture session so VoiceType actually appears in
        // System Settings → Microphone (the request-only API can be missed
        // by TCC on ad-hoc / dev-signed builds).
        Task { _ = await Permissions.forceMicrophoneRegistration() }
        _ = Permissions.requestAccessibility(prompt: true)

        menuBar = MenuBarController(
            engine: engine,
            openDashboard: { [weak self] in self?.showDashboard() },
            openSettings: { [weak self] in self?.showSettings() },
            openMemory: { [weak self] in self?.showSettings(tab: .memory) },
            openDictionary: { [weak self] in self?.showSettings(tab: .dictionary) }
        )

        hudController = HUDWindowController(engine: engine, settingsStore: settingsStore)

        // Wire hotkeys → engine (tap-toggle).
        hotkeys.onToggle = { [weak self] mode in
            Task { await self?.engine.toggleRecording(mode: mode) }
        }
        hotkeys.start()

        showDashboard()
        if !UserDefaults.standard.bool(forKey: "vt.didFirstRun") {
            UserDefaults.standard.set(true, forKey: "vt.didFirstRun")
            // Nudge them to providers on the very first run.
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

    func showDashboard() {
        if dashboardController == nil {
            dashboardController = DashboardWindowController(
                engine: engine,
                settingsStore: settingsStore,
                memory: memory,
                history: engine.history,
                openSettings: { [weak self] in self?.showSettings() },
                openProviders: { [weak self] in self?.showSettings(tab: .providers) },
                openDictionary: { [weak self] in self?.showSettings(tab: .dictionary) },
                openMemory: { [weak self] in self?.showSettings(tab: .memory) }
            )
        }
        dashboardController?.show()
    }
}
