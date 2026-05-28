import SwiftUI
import VOCACore

/// Root settings split view. Sidebar selection drives the detail pane; each
/// detail pane handles its own page chrome (header + Card stack) so the
/// shared scaffold here stays minimal.
struct SettingsView: View {
    @State var selection: SettingsTab
    @EnvironmentObject var store: SettingsStore

    init(initialTab: SettingsTab) { _selection = State(initialValue: initialTab) }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selection) { tab in
                Label(store.t(tab.localizationKey), systemImage: tab.systemImage)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selection {
                case .general: GeneralSettingsView()
                case .providers: ProvidersSettingsView()
                case .languages: LanguagesSettingsView()
                case .dictionary: DictionarySettingsView()
                case .memory: MemorySettingsView()
                case .logs: LogsSettingsView()
                case .about: AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignTokens.Color.surface)
        }
        // The design system is a single warm light palette ("Professional
        // Warmth"). Pin every settings pane to light mode so system controls
        // (Picker, TextField, Toggle) render with dark text on light chrome
        // and don't go invisible on users running macOS in Dark Mode.
        .preferredColorScheme(.light)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: store.t(.tabGeneral),
            subtitle: store.t(.generalSubtitle)
        ) {
            appearanceCard
            behaviorCard
            hotkeysCard
            toneCard
            permissionsCard
        }
    }

    /// Top-of-General language card. Uses a segmented control with two
    /// explicit options so the choice is obviously two-state and the
    /// switch is one click rather than a dropdown step.
    private var appearanceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.generalAppearanceSection))
                Text(store.t(.generalAppearanceLanguageTitle))
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                Picker("", selection: bind(\.uiLanguage)) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(store.t(.generalAppearanceLanguageHint))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var behaviorCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.generalBehaviorSection))

                ToggleRow(
                    title: store.t(.generalShowHUDTitle),
                    hint: store.t(.generalShowHUDHint),
                    isOn: bind(\.showHUD)
                )
                Divider().background(DesignTokens.Color.borderSubtle)
                ToggleRow(
                    title: store.t(.generalAdaptiveMemoryTitle),
                    hint: store.t(.generalAdaptiveMemoryHint),
                    isOn: bind(\.learningEnabled)
                )
                Divider().background(DesignTokens.Color.borderSubtle)
                ToggleRow(
                    title: store.t(.generalLearnCorrectionsTitle),
                    hint: store.t(.generalLearnCorrectionsHint),
                    isOn: bind(\.learnFromCorrections)
                )
                Divider().background(DesignTokens.Color.borderSubtle)
                ToggleRow(
                    title: store.t(.generalPlaySoundsTitle),
                    hint: store.t(.generalPlaySoundsHint),
                    isOn: bind(\.playSounds)
                )

                Divider().background(DesignTokens.Color.borderSubtle)

                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    Text(store.t(.generalInjectionTitle))
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .vtPrimaryText()
                    Picker("", selection: bind(\.injectionMethod)) {
                        ForEach(AppSettings.InjectionMethod.allCases, id: \.self) { method in
                            Text(injectionDisplayName(method)).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text(store.t(.generalInjectionHint))
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }
        }
    }

    private func injectionDisplayName(_ method: AppSettings.InjectionMethod) -> String {
        switch method {
        case .paste: return store.t(.generalInjectionPaste)
        case .typed: return store.t(.generalInjectionTyped)
        }
    }

    private var hotkeysCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.generalHotkeysSection))
                HotkeyRow(title: store.t(.hotkeyDictateTitle), keys: ["Right Option"])
                HotkeyRow(title: store.t(.hotkeyTranslateTitle), keys: ["Right Option", "Right Shift"])
                Text(store.t(.generalHotkeysNote))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var toneCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.generalToneSection))
                Text(store.t(.generalToneTitle))
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                TextField(
                    "e.g. natural, concise, faithful to the speaker",
                    text: bind(\.tone),
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .font(DesignTokens.Typography.body)
                Text(store.t(.generalToneFooter))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var permissionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.generalPermissionsSection))
                Text(store.t(.generalPermissionsBody))
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
                HStack(spacing: DesignTokens.Space.sm) {
                    Button(store.t(.generalOpenMicSettings)) { Permissions.openMicrophoneSettings() }
                        .buttonStyle(.bordered)
                    Button(store.t(.generalOpenAccessibilitySettings)) { Permissions.openAccessibilitySettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func bind<V>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: store.t(.tabAbout),
            subtitle: store.t(.aboutSubtitle)
        ) {
            Card {
                VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                    SectionTitle(store.t(.aboutDefaultsSection))
                    AboutRow(title: store.t(.aboutTranscription), detail: store.t(.aboutTranscriptionDetail))
                    AboutRow(title: store.t(.aboutRefinement), detail: store.t(.aboutRefinementDetail))
                    AboutRow(title: store.t(.aboutOffline), detail: store.t(.aboutOfflineDetail))
                }
            }

            Card {
                VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                    SectionTitle(store.t(.aboutStorageSection))
                    Text("~/Library/Application Support/VOCA")
                        .font(DesignTokens.Typography.mono)
                        .vtSecondaryText()
                    Text(store.t(.aboutStorageFooter))
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }

            Card {
                VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                    SectionTitle(store.t(.aboutSupportSection))
                    WalletRow(label: store.t(.aboutSupportEmailLabel), value: SupportInfo.email)
                    WalletRow(label: "BTC", value: SupportInfo.btc)
                    WalletRow(label: "EVM", value: SupportInfo.evm)
                    WalletRow(label: "SOL", value: SupportInfo.sol)
                    Text(store.t(.aboutSupportFooter))
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }

            HStack {
                Spacer()
                Text(store.t(.aboutPublisher))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
                Spacer()
            }
            .padding(.top, DesignTokens.Space.sm)
        }
    }
}

/// Public-by-design support addresses surfaced in About.
private enum SupportInfo {
    static let email = "valley.mirror7602@eagereverest.com"
    static let btc = "bc1pzrjrmhru0lm6g062d0nccmu0emhfmymqhacfqen3dya2985r8kvs09jxmy"
    static let evm = "0x081540Eb4c21B8Be8a652d408A4711bFaffeB5f4"
    static let sol = "GarVB5hdQ4bZ2JfJcNG8i363CL2jWBFDscwLWVNrzVxD"
}

private struct WalletRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.md) {
            Text(label)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtPrimaryText()
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(DesignTokens.Typography.mono)
                .vtSecondaryText()
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Shared building blocks

/// Standard page scaffold: surface background, large title, subtitle,
/// then a vertical stack of Cards with consistent spacing.
struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.display)
                        .vtPrimaryText()
                    Text(subtitle)
                        .font(DesignTokens.Typography.body)
                        .vtSecondaryText()
                }
                .padding(.bottom, DesignTokens.Space.xs)

                content()
            }
            .padding(.horizontal, DesignTokens.Space.xxl)
            .padding(.top, DesignTokens.Space.xl)
            .padding(.bottom, DesignTokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.Color.surface)
    }
}

/// Toggle laid out per the SC idiom: title + hint on the left, toggle on the right.
struct ToggleRow: View {
    let title: String
    let hint: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(title)
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                Text(hint)
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
            Spacer(minLength: DesignTokens.Space.md)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(DesignTokens.Color.accent)
        }
    }
}

/// Single hotkey display — label on the left, key caps on the right.
private struct HotkeyRow: View {
    let title: String
    let keys: [String]

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtPrimaryText()
            Spacer(minLength: 0)
            HStack(spacing: DesignTokens.Space.xs) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(DesignTokens.Typography.mono)
                        .vtPrimaryText()
                        .padding(.horizontal, DesignTokens.Space.sm)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                .fill(DesignTokens.Color.surfaceSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                .stroke(DesignTokens.Color.borderSubtle, lineWidth: 0.5)
                        )
                }
            }
        }
    }
}

private struct AboutRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.md) {
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtPrimaryText()
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(DesignTokens.Typography.body)
                .vtSecondaryText()
            Spacer(minLength: 0)
        }
    }
}
