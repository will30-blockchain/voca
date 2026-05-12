import SwiftUI
import VoiceTypeCore

struct LanguagesSettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.lg) {
            Text("Languages").font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Primary dictation language").font(.headline)
                Text("Auto-detect mixes Chinese/English smoothly. Pin a language if your accent confuses Whisper.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: bind(\.primaryLanguage)) {
                    ForEach(SupportedLanguage.allCases, id: \.rawValue) { l in
                        Text(l.displayName).tag(l.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Translate mode").font(.headline)
                HStack {
                    Picker("Source", selection: bind(\.translateSourceLanguage)) {
                        ForEach(SupportedLanguage.allCases, id: \.rawValue) { l in
                            Text(l.displayName).tag(l.rawValue)
                        }
                    }
                    Image(systemName: "arrow.right")
                    Picker("Target", selection: bind(\.translateTargetLanguage)) {
                        ForEach(SupportedLanguage.allCases.filter { $0 != .auto }, id: \.rawValue) { l in
                            Text(l.displayName).tag(l.rawValue)
                        }
                    }
                }
                Text("Hold Right Option + Right Shift to dictate in source and paste the translated result in target.")
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
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
