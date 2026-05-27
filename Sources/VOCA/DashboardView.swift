import SwiftUI
import VOCACore

struct DashboardView: View {
    @EnvironmentObject var engine: VOCAEngine
    @EnvironmentObject var store: SettingsStore
    @EnvironmentObject var memory: PersonalMemory
    @EnvironmentObject var history: TranscriptHistory

    let openSettings: () -> Void
    let openProviders: () -> Void
    let openDictionary: () -> Void
    let openMemory: () -> Void

    @State private var permissionTicker = 0
    /// AX trust state at the moment this view first appeared. macOS only
    /// re-reads AX trust at process start, so if this was false but the
    /// runtime check now returns true, the user granted permission while
    /// VOCA was running and a relaunch is required for global hotkeys to
    /// actually receive events.
    @State private var axGrantedAtLaunch: Bool? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xl) {
                header
                if needsRestartForAX {
                    restartBanner
                } else {
                    permissionBanner
                }
                statusCard
                if missingKey { setupCard }
                hotkeyCard
                LearnedListCard(learner: engine.learner, store: store)
                recentCard
            }
            .padding(.horizontal, DesignTokens.Space.xxl)
            .padding(.top, DesignTokens.Space.xl)
            .padding(.bottom, DesignTokens.Space.xxl)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(DesignTokens.Color.surface)
        .onAppear {
            if axGrantedAtLaunch == nil {
                axGrantedAtLaunch = Permissions.accessibilityTrusted
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            permissionTicker &+= 1
        }
    }

    /// True iff the user granted Accessibility *after* this process started.
    private var needsRestartForAX: Bool {
        let _ = permissionTicker
        guard let initial = axGrantedAtLaunch, initial == false else { return false }
        return Permissions.accessibilityTrusted
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.t(.appName))
                    .font(DesignTokens.Typography.display)
                    .vtPrimaryText()
                Text(store.t(.appTagline))
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
            }
            Spacer()
            HStack(spacing: 6) {
                Button(store.t(.dashboardDictionary), action: openDictionary)
                Button(store.t(.dashboardMemory), action: openMemory)
                Button {
                    openSettings()
                } label: {
                    Label(store.t(.dashboardSettings), systemImage: "slider.horizontal.3")
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
                        Text(store.t(.permissionsCardTitle))
                            .font(DesignTokens.Typography.headline)
                            .vtPrimaryText()
                    }

                    if !axGranted {
                        permissionRow(
                            title: store.t(.permAccessibilityTitle),
                            body: store.t(.permAccessibilityBody),
                            action: store.t(.permAccessibilityAction),
                            run: Permissions.openAccessibilitySettings
                        )
                    }
                    if !micGranted {
                        permissionRow(
                            title: store.t(.permMicTitle),
                            body: store.t(.permMicBody),
                            action: store.t(.permMicRequest),
                            secondary: (store.t(.permMicOpenSettings), Permissions.openMicrophoneSettings),
                            primaryStyle: .borderedProminent,
                            run: { Task { _ = await Permissions.forceMicrophoneRegistration() } }
                        )
                    }
                    Text(store.t(.permissionsCardFooter))
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

    /// Prominent banner shown when AX was granted mid-session — invites
    /// the user to restart so the granted permission actually takes effect.
    private var restartBanner: some View {
        Card(padding: DesignTokens.Space.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Space.md) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t(.permAXJustGrantedTitle))
                        .font(DesignTokens.Typography.headline)
                        .vtPrimaryText()
                    Text(store.t(.permAXJustGrantedBody))
                        .font(DesignTokens.Typography.body)
                        .vtSecondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DesignTokens.Space.md)
                Button(store.t(.permActionRestartNow)) {
                    Relaunch.now()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Color.accent)
                .controlSize(.large)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(DesignTokens.Color.accent.opacity(0.55), lineWidth: 1)
        )
    }

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
                    Label(store.t(.actionCancel), systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button {
                    Task { await engine.toggleRecording(mode: .transcribe) }
                } label: {
                    Label(store.t(.actionStopAndPaste), systemImage: "checkmark")
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
                Label(engineIsActive ? store.t(.actionWorking) : store.t(.actionStartDictation),
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
        case .idle: return store.t(.statusReady)
        case .recording(.transcribe): return store.t(.statusListening)
        case .recording(.translate): return store.t(.statusListeningTranslate)
        case .processing(_, let stage): return stage.label
        case .error: return store.t(.statusError)
        }
    }

    private var statusSubtitle: String {
        switch engine.state {
        case .idle:
            return store.t(.statusReadyHint)
        case .recording(.transcribe):
            return store.t(.statusListeningHint)
        case .recording(.translate):
            return store.t(.statusListeningTranslateHint)
        case .processing:
            return store.t(.statusProcessingHint)
        case .error(let msg):
            return msg
        }
    }

    // MARK: - Hotkeys

    private var hotkeyCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            SectionTitle(store.t(.hotkeysTitle))
            HStack(alignment: .top, spacing: DesignTokens.Space.md) {
                HotkeyCard(
                    title: store.t(.hotkeyDictateTitle),
                    keys: [.rightOption],
                    description: store.t(.hotkeyDictateDescription),
                    tint: DesignTokens.Color.recording
                )
                HotkeyCard(
                    title: store.t(.hotkeyTranslateTitle),
                    keys: [.rightOption, .rightShift],
                    description: store.t(.hotkeyTranslateDescription),
                    tint: DesignTokens.Color.translate
                )
            }
            Text(store.t(.hotkeysAccentNote))
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
                    Text(store.t(.setupTitle))
                        .font(DesignTokens.Typography.headline)
                        .vtPrimaryText()
                }
                Text(store.t(.setupBody))
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
                HStack(spacing: DesignTokens.Space.sm) {
                    Button(store.t(.setupOpenProviders), action: openProviders)
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.Color.accent)
                    Button(store.t(.setupUseAppleSpeech)) {
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
                    store.t(.recentTitle),
                    trailing: history.entries.isEmpty
                        ? nil
                        : AnyView(
                            Button(store.t(.actionClear), role: .destructive) { history.clear() }
                                .buttonStyle(.borderless)
                                .font(DesignTokens.Typography.captionEmphasis)
                          )
                )
                if history.entries.isEmpty {
                    EmptyState(
                        icon: "waveform.path",
                        title: store.t(.recentEmptyTitle),
                        message: store.t(.recentEmpty)
                    )
                } else {
                    VStack(spacing: DesignTokens.Space.sm) {
                        ForEach(history.entries.prefix(8)) { entry in
                            HistoryRow(entry: entry, dictateLabel: store.t(.recentDictateLabel), translateLabel: store.t(.recentTranslateLabel))
                        }
                    }
                }
                HStack {
                    Text("\(store.t(.recentTotalDictations)) \(memory.snapshot.totalDictations)")
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
    let title: String
    let keys: [Keycap.Spec]
    let description: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(DesignTokens.Typography.title2)
                    .vtPrimaryText()
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                        if index > 0 {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                                .vtTertiaryText()
                        }
                        Keycap(spec: key, tint: tint)
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

/// Vivid keycap — physical-looking key with the Mac modifier glyph
/// (⌥, ⇧) front and center, a small "R" tag indicating it's the
/// right-side key, and a subtle highlight + drop shadow so it reads as
/// a real piece of hardware rather than just text.
struct Keycap: View {
    let spec: Spec
    let tint: Color

    struct Spec: Equatable {
        let symbol: String   // SF Symbol for the modifier (option / shift)
        let label: String    // short cap label, e.g. "option"
        let side: Side
        enum Side { case left, right, none }

        static let rightOption = Spec(symbol: "option", label: "option", side: .right)
        static let rightShift = Spec(symbol: "shift", label: "shift", side: .right)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Color.surfaceElevated,
                            DesignTokens.Color.surfaceSunken
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DesignTokens.Color.border, lineWidth: 0.6)
                )
                .overlay(
                    // Top inner highlight — fakes a beveled keycap edge.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .trim(from: 0, to: 0.5)
                        .stroke(Color.white.opacity(0.7), lineWidth: 0.6)
                        .rotationEffect(.degrees(180))
                        .blendMode(.plusLighter)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 1.5, x: 0, y: 1)

            if spec.side == .right {
                Text("R")
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.leading, 6)
                    .padding(.top, 4)
            }

            VStack(spacing: 1) {
                Image(systemName: spec.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Text(spec.label)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .vtTertiaryText()
                    .tracking(0.4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 54, height: 46)
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
    let dictateLabel: String
    let translateLabel: String
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
        let label = isTranslate ? translateLabel : dictateLabel
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

/// Surfaces `CorrectionLearner.recent` on the Dashboard so the user can see
/// what was auto-learned across recent dictations. Replaces the previous
/// "only-the-5-second-toast" feedback loop, which was easy to miss.
private struct LearnedListCard: View {
    @ObservedObject var learner: CorrectionLearner
    let store: SettingsStore

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.learnedTitle))
                if learner.recent.isEmpty {
                    EmptyState(
                        icon: "sparkles",
                        title: store.t(.learnedEmptyTitle),
                        message: store.t(.learnedEmpty)
                    )
                } else {
                    VStack(spacing: DesignTokens.Space.sm) {
                        ForEach(learner.recent.prefix(12)) { entry in
                            row(for: entry)
                        }
                    }
                    Text(store.t(.learnedFooterHint))
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }
        }
    }

    private func row(for entry: CorrectionLearner.LearnedTerm) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(DesignTokens.Color.accentTint))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.term)
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                    .lineLimit(1)
                Text(Self.formatter.string(from: entry.learnedAt))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
            Spacer(minLength: DesignTokens.Space.sm)
            Button {
                learner.remove(id: entry.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .vtTertiaryText()
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(store.t(.learnedRemove))
        }
        .padding(DesignTokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(DesignTokens.Color.surfaceSunken)
        )
    }
}
