import SwiftUI
import VOCACore

struct LanguagesSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        SettingsPage(
            title: store.t(.tabLanguages),
            subtitle: store.t(.languagesSubtitle)
        ) {
            primaryCard
            translateCard
        }
    }

    private var primaryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.languagesPrimarySection))
                Text(store.t(.languagesPrimaryLabel))
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .vtPrimaryText()
                Picker("", selection: bind(\.primaryLanguage)) {
                    ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Text(store.t(.languagesPrimaryHint))
                    .font(DesignTokens.Typography.caption)
                    .vtTertiaryText()
            }
        }
    }

    private var translateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Space.md) {
                SectionTitle(store.t(.languagesTranslateSection))
                HStack(alignment: .center, spacing: DesignTokens.Space.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                        Text(store.t(.languagesSourceLabel))
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
                        Text(store.t(.languagesTargetLabel))
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
                Text(store.t(.languagesTranslateHint))
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
