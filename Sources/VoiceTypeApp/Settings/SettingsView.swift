import SwiftUI
import VoiceTypeCore

/// Root settings split view. Sidebar selection drives the detail pane; each
/// detail pane handles its own page chrome (header + Card stack) so the
/// shared scaffold here stays minimal.
struct SettingsView: View {
    @State var selection: SettingsTab

    init(initialTab: SettingsTab) { _selection = State(initialValue: initialTab) }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selection) { tab in
                Label(tab.title, systemImage: tab.systemImage)
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
                case .about: AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignTokens.Color.surface)
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: "General",
            subtitle: "Behavior, hotkeys, and the macOS permissions VoiceType needs to run."
        ) {
            behaviorCard
            hotkeysCard
            toneCard
            permissionsCard
        }
    }

    private var behaviorCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Behavior")

                ToggleRow(
                    title: "Show recording HUD",
                    hint: "A small overlay near the menu bar while you dictate.",
                    isOn: bind(\.showHUD)
                )
                Divider().background(DesignTokens.Color.borderSubtle)
                ToggleRow(
                    title: "Adaptive personal memory",
                    hint: "Learn recurring names and phrases to improve future transcripts.",
                    isOn: bind(\.learningEnabled)
                )
                Divider().background(DesignTokens.Color.borderSubtle)
                ToggleRow(
                    title: "Play subtle sounds",
                    hint: "A soft tone on start and stop. Off if you record over calls.",
                    isOn: bind(\.playSounds)
                )

                Divider().background(DesignTokens.Color.borderSubtle)

                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    Text("Injection method")
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .vtPrimaryText()
                    Picker("", selection: bind(\.injectionMethod)) {
                        ForEach(AppSettings.InjectionMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text("Paste is fastest and most reliable. Use simulated typing for apps that block paste.")
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }
        }
    }

    private var hotkeysCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Hotkeys")
                HotkeyRow(title: "Dictate", keys: ["Right Option"])
                HotkeyRow(title: "Translate", keys: ["Right Option", "Right Shift"])
                Text("Hotkeys are fixed in v1. Both modes require Accessibility permission.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var toneCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Refinement tone")
                Text("Tone hint")
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
                Text("Passed to the LLM refiner as style guidance. Plain English is fine.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var permissionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("System permissions")
                Text("VoiceType needs microphone access to listen and Accessibility access to paste into the focused app.")
                    .font(DesignTokens.Typography.body)
                    .vtSecondaryText()
                HStack(spacing: DesignTokens.Space.sm) {
                    Button("Open Microphone settings") { Permissions.openMicrophoneSettings() }
                        .buttonStyle(.bordered)
                    Button("Open Accessibility settings") { Permissions.openAccessibilitySettings() }
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
    var body: some View {
        SettingsPage(
            title: "About",
            subtitle: "A native macOS dictation and translation tool that runs on your own API keys."
        ) {
            Card {
                VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                    SectionTitle("Defaults")
                    AboutRow(
                        title: "Transcription",
                        detail: "Groq Whisper — fast and inexpensive."
                    )
                    AboutRow(
                        title: "Refinement",
                        detail: "Groq Llama 3.3 70B — quick rewrites in your tone."
                    )
                    AboutRow(
                        title: "Offline fallback",
                        detail: "Apple Speech runs entirely on-device when no API key is set."
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: DesignTokens.Space.sm) {
                    SectionTitle("Storage")
                    Text("~/Library/Application Support/VoiceType")
                        .font(DesignTokens.Typography.mono)
                        .vtSecondaryText()
                    Text("Settings, dictionary, and personal memory are persisted as JSON.")
                        .font(DesignTokens.Typography.caption)
                        .vtTertiaryText()
                }
            }
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
