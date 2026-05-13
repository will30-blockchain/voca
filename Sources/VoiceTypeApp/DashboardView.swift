import SwiftUI
import VoiceTypeCore

struct DashboardView: View {
    @EnvironmentObject var engine: VoiceTypeEngine
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var memory: PersonalMemory
    @EnvironmentObject var history: TranscriptHistory

    let openSettings: () -> Void
    let openProviders: () -> Void
    let openDictionary: () -> Void
    let openMemory: () -> Void

    @State private var permissionTicker = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                permissionBanner
                statusCard
                hotkeyCard
                if missingKey {
                    setupCard
                }
                recentCard
                footer
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.Color.surface)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            // Re-evaluate permission status periodically so the banner clears
            // as soon as the user grants access in System Settings.
            permissionTicker &+= 1
        }
    }

    private var micGranted: Bool { Permissions.microphoneStatus() == .granted }
    private var axGranted: Bool { Permissions.accessibilityTrusted }

    @ViewBuilder
    private var permissionBanner: some View {
        let _ = permissionTicker // re-render trigger
        if !micGranted || !axGranted {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.yellow)
                    Text("Permissions needed").font(.headline)
                }
                if !axGranted {
                    permissionRow(
                        title: "Accessibility",
                        body: "Required so the global Right Option hotkey works in any app and so paste can be synthesized.",
                        action: "Open Accessibility settings",
                        run: Permissions.openAccessibilitySettings
                    )
                }
                if !micGranted {
                    permissionRow(
                        title: "Microphone",
                        body: "Required to capture your speech.",
                        action: "Open Microphone settings",
                        run: Permissions.openMicrophoneSettings
                    )
                }
                Text("After enabling a permission, quit VoiceType (⌘Q) and relaunch — macOS only refreshes Accessibility trust on launch.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(Color.yellow.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private func permissionRow(title: String, body: String, action: String, run: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(body).font(DesignTokens.Font.body).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action) { run() }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                statusIndicator
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(statusSubtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if engineIsRecording {
                    Button(role: .destructive) {
                        Task { await engine.cancelRecording() }
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    Button(action: toggleTranscribe) {
                        Label("Stop & paste", systemImage: "checkmark")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    Button(action: toggleTranscribe) {
                        Label(engineIsActive ? "Working…" : "Start dictation",
                              systemImage: engineIsActive ? "ellipsis" : "mic.fill")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(engineIsActive)
                }
            }
            if engineIsRecording {
                Waveform(level: engine.recorder.level, color: indicatorColor, isLive: true)
                    .frame(height: 30)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .stroke(DesignTokens.Color.border)
        )
    }

    private var engineIsRecording: Bool {
        if case .recording = engine.state { return true }
        return false
    }

    private var engineIsActive: Bool {
        switch engine.state {
        case .recording, .processing: return true
        default: return false
        }
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.18))
                .frame(width: 64, height: 64)
            Circle()
                .fill(indicatorColor)
                .frame(width: 24, height: 24)
        }
    }

    private var indicatorColor: Color {
        switch engine.state {
        case .recording(.transcribe), .processing(.transcribe, _): return DesignTokens.Color.recording
        case .recording(.translate), .processing(.translate, _): return DesignTokens.Color.translate
        case .error: return .yellow
        default: return .secondary
        }
    }

    private var statusTitle: String {
        switch engine.state {
        case .idle: return "Ready"
        case .recording(.transcribe): return "Listening…"
        case .recording(.translate): return "Listening (translate)…"
        case .processing(_, let stage): return stage
        case .error: return "Error"
        }
    }

    private var statusSubtitle: String {
        switch engine.state {
        case .idle:
            return "Tap Right Option to start dictation. Tap again to stop and paste."
        case .recording(.transcribe):
            return "Tap Right Option again to stop. The cleaned transcript will paste at your cursor."
        case .recording(.translate):
            return "Translating from \(store.settings.translateSourceLanguage) → \(store.settings.translateTargetLanguage). Tap Right Option to stop."
        case .processing:
            return "Working through the pipeline — hang tight."
        case .error(let msg):
            return msg
        }
    }

    private func toggleTranscribe() {
        Task { await engine.toggleRecording(mode: .transcribe) }
    }

    // MARK: - Hotkey card

    private var hotkeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hotkeys").font(.headline)
            HotkeyRow(
                title: "Dictate",
                keys: ["Right Option"],
                description: "Tap once to start, tap again to stop and paste.",
                tint: DesignTokens.Color.recording
            )
            HotkeyRow(
                title: "Translate",
                keys: ["Right Option", "Right Shift"],
                description: "Hold Right Shift while tapping Right Option to start a translation. Tap Right Option again to stop.",
                tint: DesignTokens.Color.translate
            )
            Text("Right Option held continuously (longer than 0.5 s) still works for accent input — Option+E for é, etc.")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(card)
    }

    // MARK: - Setup card (shown when no Groq key yet)

    private var missingKey: Bool {
        store.settings.credentials.groqAPIKey.isEmpty &&
        store.settings.credentials.openaiAPIKey.isEmpty &&
        store.settings.credentials.anthropicAPIKey.isEmpty &&
        store.settings.credentials.deepgramAPIKey.isEmpty &&
        store.settings.sttProvider != .appleSpeech
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add an API key to start dictating", systemImage: "key.fill")
                .font(.headline)
            Text("VoiceType uses your own API keys. The fastest free path is Groq — one key powers both the Whisper transcription and the LLM editor. Grab a key from console.groq.com/keys, then paste it in Settings → Providers.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Providers") { openProviders() }
                    .buttonStyle(.borderedProminent)
                Button("Use Apple Speech instead") {
                    store.update { $0.sttProvider = .appleSpeech }
                    store.update { $0.llmProvider = .disabled }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(card.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Color.accent, lineWidth: 1.5)
        )
    }

    // MARK: - Recent activity

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent dictations").font(.headline)
                Spacer()
                if !history.entries.isEmpty {
                    Button("Clear", role: .destructive) { history.clear() }
                        .buttonStyle(.borderless)
                }
            }
            if history.entries.isEmpty {
                Text("Your last few dictations will show up here. Right now there's nothing yet — try a quick test once your key is in.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .fill(DesignTokens.Color.surfaceElevated)
                    )
            } else {
                VStack(spacing: 6) {
                    ForEach(history.entries.prefix(8)) { entry in
                        HistoryRow(entry: entry)
                    }
                }
            }
        }
        .padding(20)
        .background(card)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Settings") { openSettings() }
            Button("Dictionary") { openDictionary() }
            Button("Memory") { openMemory() }
            Spacer()
            Text("\(memory.snapshot.totalDictations) total dictations")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .fill(DesignTokens.Color.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DesignTokens.Color.border)
            )
    }
}

private struct HotkeyRow: View {
    let title: String
    let keys: [String]
    let description: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle().fill(tint).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title).font(.body.weight(.semibold))
                    ForEach(keys, id: \.self) { k in
                        Text(k)
                            .font(DesignTokens.Font.mono)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6).fill(DesignTokens.Color.surface)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignTokens.Color.border))
                    }
                }
                Text(description)
                    .foregroundStyle(.secondary)
                    .font(DesignTokens.Font.body)
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: TranscriptHistory.Entry
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.mode == "translate" ? "Translate" : "Dictate")
                        .font(DesignTokens.Font.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.mode == "translate" ? DesignTokens.Color.translate.opacity(0.18) : DesignTokens.Color.recording.opacity(0.18))
                        )
                        .foregroundStyle(.secondary)
                    Text(Self.formatter.string(from: entry.date))
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(entry.text)
                    .font(DesignTokens.Font.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(entry.text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(DesignTokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(DesignTokens.Color.border)
        )
    }
}
