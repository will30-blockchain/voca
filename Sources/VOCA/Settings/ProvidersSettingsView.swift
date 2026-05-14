import SwiftUI
import VOCACore

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: "Providers",
            subtitle: "Pick the models that power transcription and refinement. Groq runs Whisper-large at a fraction of OpenAI's price."
        ) {
            transcriptionCard
            refinementCard
            keysCard
        }
    }

    // MARK: - Cards

    private var transcriptionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Transcription")

                LabelledControl(title: "Provider") {
                    Picker("", selection: bind(\.sttProvider)) {
                        ForEach(STTProviderID.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: store.settings.sttProvider) { _, newValue in
                        if store.settings.sttModel.isEmpty || isDefaultSTTModel() {
                            store.update { $0.sttModel = newValue.defaultModel }
                        }
                    }
                }

                LabelledControl(
                    title: "Model",
                    hint: "Pick a preset or type a custom model name for newly released models."
                ) {
                    ModelPicker(
                        known: store.settings.sttProvider.knownModels,
                        selection: bind(\.sttModel)
                    )
                }
            }
        }
    }

    private var refinementCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("LLM refinement")

                LabelledControl(
                    title: "Provider",
                    hint: "Refinement cleans punctuation and disfluencies. Disable to paste the raw transcript."
                ) {
                    Picker("", selection: bind(\.llmProvider)) {
                        ForEach(LLMProviderID.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: store.settings.llmProvider) { _, newValue in
                        if store.settings.llmModel.isEmpty || isDefaultLLMModel() {
                            store.update { $0.llmModel = newValue.defaultModel }
                        }
                    }
                }

                LabelledControl(title: "Model") {
                    ModelPicker(
                        known: store.settings.llmProvider.knownModels,
                        selection: bind(\.llmModel)
                    )
                    .disabled(store.settings.llmProvider == .disabled)
                }
            }
        }
    }

    private var keysCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("API keys")
                APIKeyField(title: "Groq", placeholder: "gsk_…", key: bind(\.credentials.groqAPIKey))
                APIKeyField(title: "OpenAI", placeholder: "sk-…", key: bind(\.credentials.openaiAPIKey))
                APIKeyField(title: "Anthropic", placeholder: "sk-ant-…", key: bind(\.credentials.anthropicAPIKey))
                APIKeyField(title: "Deepgram", placeholder: "key", key: bind(\.credentials.deepgramAPIKey))
                Text("Keys are stored locally in ~/Library/Application Support/VOCA/settings.json. Keychain storage is on the roadmap.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    // MARK: - Helpers

    private func isDefaultSTTModel() -> Bool {
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

// MARK: - Building blocks

/// Standard "title above field" form row. Optional hint sits below in tertiary text.
private struct LabelledControl<Content: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtPrimaryText()
            content()
            if let hint {
                Text(hint)
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }
}

private struct ModelPicker: View {
    let known: [(id: String, label: String)]
    @Binding var selection: String
    @State private var isCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Picker("", selection: pickerBinding) {
                ForEach(known, id: \.id) { model in
                    Text(model.label).tag(model.id)
                }
                Text("Custom…").tag("__custom__")
            }
            .pickerStyle(.menu)
            .labelsHidden()

            if isCustom || known.first(where: { $0.id == selection }) == nil {
                TextField("Custom model name", text: $selection)
                    .textFieldStyle(.roundedBorder)
                    .font(DesignTokens.Typography.mono)
                    .onAppear { isCustom = true }
            }
        }
    }

    private var pickerBinding: Binding<String> {
        Binding(
            get: { isCustom ? "__custom__" : selection },
            set: { value in
                if value == "__custom__" {
                    isCustom = true
                } else {
                    isCustom = false
                    selection = value
                }
            }
        )
    }
}

/// API key entry: title above, reveal/hide button next to the field. No inline label.
private struct APIKeyField: View {
    let title: String
    let placeholder: String
    @Binding var key: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasis)
                .vtPrimaryText()
            HStack(spacing: DesignTokens.Space.sm) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $key)
                    } else {
                        SecureField(placeholder, text: $key)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(DesignTokens.Typography.mono)

                Button(isRevealed ? "Hide" : "Show") { isRevealed.toggle() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
