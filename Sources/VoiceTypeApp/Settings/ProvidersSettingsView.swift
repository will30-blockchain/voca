import SwiftUI
import VoiceTypeCore

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
                header

                section("Transcription") {
                    Picker("Provider", selection: bind(\.sttProvider)) {
                        ForEach(STTProviderID.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .onChange(of: store.settings.sttProvider) { _, newValue in
                        if store.settings.sttModel.isEmpty || isDefaultModel() {
                            store.update { $0.sttModel = newValue.defaultModel }
                        }
                    }

                    TextField("Model", text: bind(\.sttModel))
                        .textFieldStyle(.roundedBorder)
                }

                section("LLM refinement") {
                    Picker("Provider", selection: bind(\.llmProvider)) {
                        ForEach(LLMProviderID.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .onChange(of: store.settings.llmProvider) { _, newValue in
                        if store.settings.llmModel.isEmpty || isDefaultLLMModel() {
                            store.update { $0.llmModel = newValue.defaultModel }
                        }
                    }

                    TextField("Model", text: bind(\.llmModel))
                        .textFieldStyle(.roundedBorder)
                        .disabled(store.settings.llmProvider == .disabled)
                }

                section("API keys") {
                    APIKeyField(title: "Groq", systemImage: "bolt.fill", key: bind(\.credentials.groqAPIKey))
                    APIKeyField(title: "OpenAI", systemImage: "circle.hexagongrid.fill", key: bind(\.credentials.openaiAPIKey))
                    APIKeyField(title: "Anthropic", systemImage: "sparkles", key: bind(\.credentials.anthropicAPIKey))
                    APIKeyField(title: "Deepgram", systemImage: "waveform.path", key: bind(\.credentials.deepgramAPIKey))
                    Text("Keys are stored locally in ~/Library/Application Support/VoiceType/settings.json. Move to Keychain is on the roadmap.")
                        .font(DesignTokens.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Providers").font(.title2.bold())
            Text("Pick the model that powers your transcription and refinement. Cheaper providers like Groq run Whisper-large at a fraction of OpenAI's price.")
                .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Color.border)
        )
    }

    private func isDefaultModel() -> Bool {
        STTProviderID.allCases.contains { $0.defaultModel == store.settings.sttModel }
    }
    private func isDefaultLLMModel() -> Bool {
        LLMProviderID.allCases.contains { $0.defaultModel == store.settings.llmModel }
    }

    private func bind<V>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct APIKeyField: View {
    let title: String
    let systemImage: String
    @Binding var key: String
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Group {
                    if reveal {
                        TextField("API key", text: $key)
                    } else {
                        SecureField("API key", text: $key)
                    }
                }
                .textFieldStyle(.roundedBorder)
                Button(reveal ? "Hide" : "Show") { reveal.toggle() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
