import SwiftUI
import VOCACore

struct ProvidersSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: store.t(.tabProviders),
            subtitle: store.t(.providersSubtitle)
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
                SectionTitle(store.t(.providersTranscriptionSection))

                LabelledControl(title: store.t(.providersProviderLabel)) {
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
                    title: store.t(.providersModelLabel),
                    hint: store.t(.providersModelHint)
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
                SectionTitle(store.t(.providersLLMSection))

                LabelledControl(
                    title: store.t(.providersProviderLabel),
                    hint: store.t(.providersLLMHint)
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

                LabelledControl(title: store.t(.providersModelLabel)) {
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
                SectionTitle(store.t(.providersKeysSection))
                APIKeyField(title: "Groq", placeholder: "gsk_…", key: bind(\.credentials.groqAPIKey))
                APIKeyField(title: "OpenAI", placeholder: "sk-…", key: bind(\.credentials.openaiAPIKey))
                APIKeyField(title: "Anthropic", placeholder: "sk-ant-…", key: bind(\.credentials.anthropicAPIKey))
                APIKeyField(title: "Deepgram", placeholder: "key", key: bind(\.credentials.deepgramAPIKey))
                Text(store.t(.providersKeysFooter))
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
/// Two-state field. Locked by default — value is hidden behind dots and
/// the right-hand button reads "Edit". Tapping Edit unlocks the field so
/// the user can paste a new key; Save commits to the binding (which
/// writes to Keychain), Cancel reverts the draft. Designed to match the
/// usual UX for sensitive credentials (1Password, system Settings, etc.)
/// where the input is never accidentally clicked into.
private struct APIKeyField: View {
    let title: String
    let placeholder: String
    @Binding var key: String

    @EnvironmentObject var store: SettingsStore

    @State private var isEditing = false
    @State private var isRevealed = false
    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            // Header row: title + status badge ("Configured" when key is set).
            HStack(spacing: 6) {
                Text(title)
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                if !isEditing && !key.isEmpty {
                    Text(store.t(.providersConfigured))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.success)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DesignTokens.Color.success.opacity(0.12))
                        )
                }
                Spacer(minLength: 0)
            }

            // Input row: depends on mode.
            if isEditing {
                HStack(spacing: DesignTokens.Space.sm) {
                    Group {
                        if isRevealed {
                            TextField(placeholder, text: $draft)
                        } else {
                            SecureField(placeholder, text: $draft)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(DesignTokens.Typography.mono)
                    .focused($fieldFocused)
                    .onSubmit(save)

                    Button(isRevealed ? store.t(.providersHide) : store.t(.providersShow)) {
                        isRevealed.toggle()
                    }
                    .buttonStyle(.bordered)

                    Button(store.t(.providersCancel), action: cancel)
                        .buttonStyle(.bordered)
                    Button(store.t(.providersSave), action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.Color.accent)
                        .keyboardShortcut(.return, modifiers: [])
                }
            } else {
                HStack(spacing: DesignTokens.Space.sm) {
                    // Read-only placeholder. Looks deliberately inert so the
                    // user knows they have to click Edit to change it.
                    Text(key.isEmpty ? store.t(.providersNotSet) : String(repeating: "•", count: 16))
                        .font(DesignTokens.Typography.mono)
                        .foregroundStyle(key.isEmpty
                                         ? DesignTokens.Color.textTertiary
                                         : DesignTokens.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(DesignTokens.Color.surfaceSunken.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DesignTokens.Color.borderSubtle, lineWidth: 0.5)
                        )

                    Button(store.t(.providersEdit), action: beginEditing)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func beginEditing() {
        draft = key
        isEditing = true
        isRevealed = false
        // Give SwiftUI a beat to swap the layout in before requesting focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            fieldFocused = true
        }
    }

    private func save() {
        // Empty draft → clears the key (Keychain.write does this via delete).
        key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        isRevealed = false
        draft = ""
    }

    private func cancel() {
        isEditing = false
        isRevealed = false
        draft = ""
    }
}
