import Foundation
import Combine

/// Persists non-secret app preferences to
/// ~/Library/Application Support/VOCA/settings.json. API keys live in the
/// macOS Keychain (`com.voca.api-key.*`) and are accessed via the
/// `ProviderCredentials` façade — they never touch the JSON file.
///
/// On first launch of the Keychain-backed version, the init migrates any
/// pre-existing key material from `settings.json` (older builds wrote
/// `credentials.groqAPIKey` etc. plaintext) into Keychain and rewrites the
/// file without those fields, with 0600 permissions.
@MainActor
public final class SettingsStore: ObservableObject {
    @Published public private(set) var settings: AppSettings

    private let url: URL

    public init() {
        self.url = SupportDirectory.file("settings.json")

        // Step 1: load whatever's on disk.
        let raw = try? Data(contentsOf: url)
        if let raw, var decoded = try? JSONDecoder().decode(AppSettings.self, from: raw) {
            // Migration: older builds saved Chinese as the script-agnostic
            // "zh"; we now require explicit "zh-Hant" or "zh-Hans" so the
            // LLM can pick the right character set. Default to Traditional
            // on migration since the original picker label was "中文" and
            // the project itself ships with a Traditional Chinese UI.
            if decoded.primaryLanguage == "zh" { decoded.primaryLanguage = "zh-Hant" }
            if decoded.translateSourceLanguage == "zh" { decoded.translateSourceLanguage = "zh-Hant" }
            if decoded.translateTargetLanguage == "zh" { decoded.translateTargetLanguage = "zh-Hant" }
            self.settings = decoded
        } else {
            self.settings = .default
        }

        // Step 2: one-time migration of plaintext API keys from older
        // settings.json into Keychain.
        if let raw {
            migrateLegacyKeysIfNeeded(rawJSON: raw)
        }

        // Step 3: re-save so the file is normalised (no key fields) and
        // its permissions are locked down to 0600.
        save()
    }

    public func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        save()
    }

    public func replace(with new: AppSettings) {
        settings = new
        save()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: url, options: .atomic)
            // Lock the file down — even though we no longer write keys
            // here, the settings file still reveals provider choice etc.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            AppLog.app.error("Failed to save settings: \(String(describing: error), privacy: .public)")
        }
    }

    private func migrateLegacyKeysIfNeeded(rawJSON: Data) {
        // Parse just enough of the old shape to extract keys. The legacy
        // file had: { "credentials": { "groqAPIKey": "...", ... }, ... }.
        guard let root = try? JSONSerialization.jsonObject(with: rawJSON) as? [String: Any],
              let creds = root["credentials"] as? [String: Any] else {
            return
        }

        let migrated: [(Keychain.Key, String)] = [
            (.groq, creds["groqAPIKey"] as? String ?? ""),
            (.openai, creds["openaiAPIKey"] as? String ?? ""),
            (.anthropic, creds["anthropicAPIKey"] as? String ?? ""),
            (.deepgram, creds["deepgramAPIKey"] as? String ?? "")
        ]
        var moved = 0
        for (key, value) in migrated where !value.isEmpty {
            // Only write if Keychain is currently empty — never overwrite a
            // newer Keychain value with a stale plaintext one.
            if Keychain.read(key).isEmpty {
                if Keychain.write(key, value: value) { moved += 1 }
            }
        }
        if moved > 0 {
            AppLog.app.info("Migrated \(moved, privacy: .public) API key(s) from settings.json into Keychain")
        }
        // Note: the save() call after init() rewrites the file without the
        // `credentials.*APIKey` values because the new ProviderCredentials
        // encodes as an empty dict. So no extra scrubbing needed.
    }

    public var storagePath: URL { url }

    /// Convenience for views: localised lookup that re-renders automatically
    /// when the user changes the UI language (since views observe this store
    /// as an @EnvironmentObject).
    public func t(_ key: L10n) -> String {
        key.text(settings.uiLanguage)
    }
}
