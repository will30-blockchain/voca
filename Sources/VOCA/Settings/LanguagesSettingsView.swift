import SwiftUI
import VOCACore

struct LanguagesSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: "Languages",
            subtitle: "Set your dictation language and the source-target pair used in translate mode."
        ) {
            primaryCard
            translateCard
        }
    }

    private var primaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Primary dictation")
                Text("Language")
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                Picker("", selection: bind(\.primaryLanguage)) {
                    ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Text("Auto-detect mixes Chinese and English smoothly. Pin a language if your accent confuses Whisper.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var translateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle("Translate mode")
                HStack(alignment: .center, spacing: DesignTokens.Space.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text("Source")
                            .font(DesignTokens.Typography.bodyEmphasis)
                            .vtPrimaryText()
                        Picker("", selection: bind(\.translateSourceLanguage)) {
                            ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                                Text(language.displayName).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .padding(.top, DesignTokens.Space.lg)

                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text("Target")
                            .font(DesignTokens.Typography.bodyEmphasis)
                            .vtPrimaryText()
                        Picker("", selection: bind(\.translateTargetLanguage)) {
                            ForEach(SupportedLanguage.allCases.filter { $0 != .auto }, id: \.rawValue) { language in
                                Text(language.displayName).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                Text("Hold Right Option + Right Shift to dictate in the source language and paste the translated result in the target language.")
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
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
