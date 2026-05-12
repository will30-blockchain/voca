import SwiftUI
import VoiceTypeCore

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
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
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
            .padding(24)
        }
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Text("General").font(.title2.bold())

            Toggle("Show recording HUD", isOn: bind(\.showHUD))
            Toggle("Adaptive personal memory", isOn: bind(\.learningEnabled))
            Toggle("Play subtle sounds", isOn: bind(\.playSounds))

            Picker("Injection method", selection: bind(\.injectionMethod)) {
                ForEach(AppSettings.InjectionMethod.allCases, id: \.self) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                Text("Hotkeys")
                    .font(.headline)
                HotkeyRow(title: "Transcribe", description: "Right Option")
                HotkeyRow(title: "Translate", description: "Right Option + Right Shift")
                Text("Hotkeys are fixed in v1 — both keys require Accessibility permission.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tone hint for LLM refinement").font(.headline)
                TextField("e.g. natural, concise, faithful to the speaker", text: bind(\.tone), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions").font(.headline)
                HStack(spacing: 12) {
                    Button("Open Microphone settings") { Permissions.openMicrophoneSettings() }
                    Button("Open Accessibility settings") { Permissions.openAccessibilitySettings() }
                }
            }

            Spacer()
        }
    }

    private func bind<V>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct HotkeyRow: View {
    let title: String
    let description: String
    var body: some View {
        HStack {
            Text(title).font(.body)
            Spacer()
            Text(description)
                .font(DesignTokens.Font.mono)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(DesignTokens.Color.surfaceElevated)
                )
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VoiceType").font(.largeTitle.bold())
            Text("A native macOS dictation and translation tool that runs on your own API keys.")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Defaults")
                    .font(.headline)
                Text("• Groq Whisper for transcription (fast, cheap)")
                Text("• Groq Llama 3.3 70B for LLM refinement")
                Text("• Fall back to Apple Speech for offline use")
            }
            .font(DesignTokens.Font.body)
            Spacer()
            Text("Storage: ~/Library/Application Support/VoiceType")
                .font(DesignTokens.Font.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
