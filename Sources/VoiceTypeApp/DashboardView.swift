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
            VStack(alignment: .leading, spacing: DesignTokens.Space.xl) {
                header
                permissionBanner
                statusCard
                if missingKey { setupCard }
                hotkeyCard
                recentCard
            }
            .padding(.horizontal, DesignTokens.Space.xxl)
            .padding(.top, DesignTokens.Space.xl)
            .padding(.bottom, DesignTokens.Space.xxl)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(DesignTokens.Color.surface)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            permissionTicker &+= 1
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("VoiceType")
                    .font(DesignTokens.Typography.display)
                    .vtPrimaryText()
                Text("Dictation and translation, on your own keys.")
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
            }
            Spacer()
            HStack(spacing: 6) {
                Button("Dictionary", action: openDictionary)
                Button("Memory", action: openMemory)
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Permissions

    private var micGranted: Bool { Permissions.microphoneStatus() == .granted }
    private var axGranted: Bool { Permissions.accessibilityTrusted }

    @ViewBuilder
    private var permissionBanner: some View {
        let _ = permissionTicker
        if !micGranted || !axGranted {
            Card(padding: DesignTokens.Space.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DesignTokens.Color.warning)
                        Text("Finish setup")
                            .font(DesignTokens.Typography.headline)
                            .vtPrimaryText()
                    }

                    if !axGranted {
                        permissionRow(
                            title: "Accessibility",
                            body: "Lets the Right Option hotkey work in any app and lets VoiceType paste at your cursor.",
                            action: "Open Accessibility",
                            run: Permissions.openAccessibilitySettings
                        )
                    }
                    if !micGranted {
                        permissionRow(
                            title: "Microphone",
                            body: "Captures your speech. If VoiceType doesn't appear in System Settings, click Request below.",
                            action: "Request",
                            secondary: ("Open settings", Permissions.openMicrophoneSettings),
                            primaryStyle: .borderedProminent,
                            run: { Task { _ = await Permissions.forceMicrophoneRegistration() } }
                        )
                    }
                    Text("After enabling a permission, quit VoiceType (⌘Q) and relaunch — macOS only refreshes Accessibility trust on launch.")
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .strokeBorder(DesignTokens.Color.warning.opacity(0.45), lineWidth: 1)
            )
        }
    }

    private func permissionRow(
        title: String,
        body: String,
        action: String,
        secondary: (String, () -> Void)? = nil,
        primaryStyle: PermissionButtonStyle = .bordered,
        run: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignTokens.Typography.bodyEmphasis).vtPrimaryText()
                Text(body).font(DesignTokens.Typography.body).vtSecondaryText()
            }
            Spacer(minLength: 0)
            Group {
                switch primaryStyle {
                case .borderedProminent:
                    Button(action, action: run).buttonStyle(.borderedProminent).tint(DesignTokens.Color.accent)
                case .bordered:
                    Button(action, action: run).buttonStyle(.bordered)
                }
            }
            if let secondary {
                Button(secondary.0, action: secondary.1).buttonStyle(.bordered)
            }
        }
    }

    private enum PermissionButtonStyle { case bordered, borderedProminent }

    // MARK: - Status

    private var statusCard: some View {
        Card(padding: DesignTokens.Space.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                HStack(alignment: .center, spacing: DesignTokens.Space.lg) {
                    statusIndicator
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text(statusTitle)
                            .font(DesignTokens.Typography.title)
                            .vtPrimaryText()
                        Text(statusSubtitle)
                            .font(DesignTokens.Typography.body)
                            .vtSecondaryText()
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DesignTokens.Space.md)
                    actionButtons
                }
                if engineIsRecording {
                    Waveform(recorder: engine.recorder, color: indicatorColor, isLive: true)
                        .frame(height: 36)
                } else if let stage = engineProcessingStage {
                    PipelineProgress(stage: stage, tint: indicatorColor)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if engineIsRecording {
            HStack(spacing: DesignTokens.Space.sm) {
                Button(role: .destructive) {
                    Task { await engine.cancelRecording() }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button {
                    Task { await engine.toggleRecording(mode: .transcribe) }
                } label: {
                    Label("Stop & paste", systemImage: "checkmark")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.accent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
            }
        } else {
            Button {
                Task { await engine.toggleRecording(mode: .transcribe) }
            } label: {
                Label(engineIsActive ? "Working…" : "Start dictation",
                      systemImage: engineIsActive ? "ellipsis" : "mic.fill")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.accent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(engineIsActive)
        }
    }

    private var engineIsActive: Bool {
        switch engine.state {
        case .recording, .processing: return true
        default: return false
        }
    }

    private var engineIsRecording: Bool {
        if case .recording = engine.state { return true }
        return false
    }

    private var engineProcessingStage: ProcessingStage? {
        if case .processing(_, let stage) = engine.state { return stage }
        return nil
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.16))
                .frame(width: 56, height: 56)
            Circle()
                .fill(indicatorColor)
                .frame(width: 16, height: 16)
        }
    }

    private var indicatorColor: Color {
        switch engine.state {
        case .recording(.transcribe), .processing(.transcribe, _): return DesignTokens.Color.recording
        case .recording(.translate), .processing(.translate, _): return DesignTokens.Color.translate
        case .error: return DesignTokens.Color.warning
        default: return DesignTokens.Color.textTertiary
        }
    }

    private var statusTitle: String {
        switch engine.state {
        case .idle: return "Ready"
        case .recording(.transcribe): return "Listening"
        case .recording(.translate): return "Listening · Translate"
        case .processing(_, let stage): return stage.label
        case .error: return "Error"
        }
    }

    private var statusSubtitle: String {
        switch engine.state {
        case .idle:
            return "Tap Right Option to start dictation. Tap again to stop and paste."
        case .recording(.transcribe):
            return "Tap Right Option again — or press Return — to stop and paste."
        case .recording(.translate):
            return "Translating \(store.settings.translateSourceLanguage) → \(store.settings.translateTargetLanguage). Tap Right Option to stop."
        case .processing:
            return "Working through the pipeline — hang tight."
        case .error(let msg):
            return msg
        }
    }

    // MARK: - Hotkeys

    private var hotkeyCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            SectionTitle("Hotkeys")
            HStack(alignment: .top, spacing: DesignTokens.Space.md) {
                HotkeyCard(
                    icon: "waveform",
                    title: "Dictate",
                    keys: ["Right Option"],
                    description: "Tap once to start, tap again to stop and paste.",
                    tint: DesignTokens.Color.recording
                )
                HotkeyCard(
                    icon: "character.bubble",
                    title: "Translate",
                    keys: ["Right Option", "Right Shift"],
                    description: "Hold Right Shift while tapping Right Option. Tap Right Option again to stop.",
                    tint: DesignTokens.Color.translate
                )
            }
            Text("Right Option held continuously (longer than 0.5 s) still works for accent input — Option+E for é, etc.")
                .font(DesignTokens.Typography.caption)
                .vtTertiaryText()
        }
    }

    // MARK: - Setup card

    private var missingKey: Bool {
        store.settings.credentials.groqAPIKey.isEmpty &&
        store.settings.credentials.openaiAPIKey.isEmpty &&
        store.settings.credentials.anthropicAPIKey.isEmpty &&
        store.settings.credentials.deepgramAPIKey.isEmpty &&
        store.settings.sttProvider != .appleSpeech
    }

    private var setupCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(DesignTokens.Color.accent)
                    Text("Add an API key to start dictating")
                        .font(DesignTokens.Typography.headline)
                        .vtPrimaryText()
                }
                Text("VoiceType runs on your own API keys. The cheapest fast path is Groq — one key powers both the Whisper transcription and the LLM editor.")
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
                HStack(spacing: DesignTokens.Space.sm) {
                    Button("Open Providers", action: openProviders)
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.Color.accent)
                    Button("Use Apple Speech instead") {
                        store.update { $0.sttProvider = .appleSpeech }
                        store.update { $0.llmProvider = .disabled }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(DesignTokens.Color.accent.opacity(0.55), lineWidth: 1)
        )
    }

    // MARK: - Recent

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(
                    "Recent dictations",
                    trailing: history.entries.isEmpty
                        ? nil
                        : AnyView(
                            Button("Clear", role: .destructive) { history.clear() }
                                .buttonStyle(.borderless)
                                .font(DesignTokens.Typography.captionEmphasis)
                          )
                )
                if history.entries.isEmpty {
                    EmptyState(
                        icon: "waveform.path",
                        title: "Nothing yet",
                        message: "Your last dictations will appear here once you've spoken into the meter."
                    )
                } else {
                    VStack(spacing: DesignTokens.Space.sm) {
                        ForEach(history.entries.prefix(8)) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
                HStack {
                    Text("Total dictations: \(memory.snapshot.totalDictations)")
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Subcomponents

/// Hotkey card — big icon on top, mode title, key combo chips, then a
/// one-line description. Two of these sit side-by-side so the user sees
/// the two modes as visually-distinct first-class actions.
private struct HotkeyCard: View {
    let icon: String
    let title: String
    let keys: [String]
    let description: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(DesignTokens.Typography.title2)
                    .vtPrimaryText()
                HStack(spacing: 6) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                        if index > 0 {
                            Text("+")
                                .font(DesignTokens.Typography.caption)
                                .vtTertiaryText()
                        }
                        Text(key)
                            .font(DesignTokens.Typography.mono)
                            .vtPrimaryText()
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(DesignTokens.Color.surfaceSunken)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(DesignTokens.Color.borderSubtle, lineWidth: 0.5)
                            )
                    }
                }
            }

            Text(description)
                .font(DesignTokens.Typography.body)
                .vtSecondaryText()
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(DesignTokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(DesignTokens.Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(DesignTokens.Color.border, lineWidth: 0.5)
        )
    }
}

/// Determinate progress bar shown during the .processing pipeline. Each
/// pipeline stage maps to a known fraction (see ProcessingStage.progress)
/// so the user gets a sense of where they are in the round-trip.
struct PipelineProgress: View {
    let stage: ProcessingStage
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(DesignTokens.Color.surfaceSunken)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tint)
                        .frame(width: proxy.size.width * CGFloat(stage.progress))
                        .animation(.easeOut(duration: 0.4), value: stage)
                }
            }
            .frame(height: 6)
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 12, height: 12)
                Text(stage.label)
                    .font(DesignTokens.Typography.caption)
                    .vtSecondaryText()
                Spacer()
                Text("\(Int(stage.progress * 100))%")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .vtTertiaryText()
                    .monospacedDigit()
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
        HStack(alignment: .top, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                HStack(spacing: 6) {
                    badge
                    Text(Self.formatter.string(from: entry.date))
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
                Text(entry.text)
                    .font(DesignTokens.Typography.body)
                    .vtPrimaryText()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(entry.text, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .regular))
                    .vtTertiaryText()
            }
            .buttonStyle(.borderless)
            .help("Copy to clipboard")
        }
        .padding(DesignTokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(DesignTokens.Color.surfaceSunken)
        )
    }

    private var badge: some View {
        let isTranslate = entry.mode == "translate"
        let tint = isTranslate ? DesignTokens.Color.translate : DesignTokens.Color.accent
        let label = isTranslate ? "Translate" : "Dictate"
        return Text(label)
            .font(DesignTokens.Typography.captionEmphasis)
            .foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.10))
            )
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: DesignTokens.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .vtTertiaryText()
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtSecondaryText()
            Text(message)
                .font(DesignTokens.Typography.caption)
                .vtTertiaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, DesignTokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(DesignTokens.Color.surfaceSunken)
        )
    }
}
