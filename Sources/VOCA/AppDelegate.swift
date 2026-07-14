import AppKit
import SwiftUI
import VOCACore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let memory = PersonalMemory()
    let dictionary = UserDictionary()
    let injector = TextInjector()
    let hotkeys = HotkeyManager()
    let log = LogStore()
    lazy var engine = VOCAEngine(
        settingsStore: settingsStore,
        memory: memory,
        dictionary: dictionary,
        recorder: AudioRecorder(),
        injector: injector,
        log: log
    )

    private var menuBar: MenuBarController?
    private var hudController: HUDWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var dashboardController: DashboardWindowController?
    private var toastController: ToastWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("VOCA launched.")

        // Install a proper main menu so Cmd+C / Cmd+V / Cmd+X / Cmd+A
        // route through the responder chain into the focused text field.
        // Without this the API-key fields silently swallow paste.
        NSApp.mainMenu = MainMenu.install(language: settingsStore.settings.uiLanguage)

        // Request mic + accessibility ASAP so the user only sees the system
        // prompts once, not on the first dictation press. forceMicrophone…
        // opens a tiny capture session so VOCA actually appears in
        // System Settings → Microphone (the request-only API can be missed
        // by TCC on ad-hoc / dev-signed builds).
        Task { _ = await Permissions.forceMicrophoneRegistration() }

        menuBar = MenuBarController(
            engine: engine,
            openDashboard: { [weak self] in self?.showDashboard() },
            openSettings: { [weak self] in self?.showSettings() },
            openMemory: { [weak self] in self?.showSettings(tab: .memory) },
            openDictionary: { [weak self] in self?.showSettings(tab: .dictionary) }
        )

        hudController = HUDWindowController(engine: engine, settingsStore: settingsStore)
        toastController = ToastWindowController(learner: engine.learner, settingsStore: settingsStore)

        // Wire hotkeys → engine (tap-toggle + ESC to cancel).
        hotkeys.onToggle = { [weak self] mode in
            Task { await self?.engine.toggleRecording(mode: mode) }
        }
        hotkeys.onEscape = { [weak self] in
            // cancelRecording is a no-op outside .recording, so this is
            // safe to fire on every ESC press globally.
            Task { await self?.engine.cancelRecording() }
        }
        // Accessibility gates the global hotkey tap. Prompt only ONCE, and
        // only start the tap when already trusted — creating a session event
        // tap while untrusted fails and can surface a *second* system prompt.
        // macOS only re-reads AX trust at process start, so an untrusted user
        // grants access and relaunches (the Dashboard shows a restart banner).
        if Permissions.accessibilityTrusted {
            hotkeys.start()
        } else {
            _ = Permissions.requestAccessibility(prompt: true)
        }

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
                dictionary: dictionary,
                log: log
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
