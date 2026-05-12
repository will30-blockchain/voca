import Foundation
import Combine

/// Persists AppSettings to ~/Library/Application Support/VoiceType/settings.json.
/// API keys are stored in the file plain-text for v1 simplicity; future versions
/// should move keys into Keychain. Marked TODO.
@MainActor
public final class SettingsStore: ObservableObject {
    @Published public private(set) var settings: AppSettings

    private let url: URL

    public init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("VoiceType", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.url = dir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
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
        } catch {
            AppLog.app.error("Failed to save settings: \(String(describing: error), privacy: .public)")
        }
    }

    public var storagePath: URL { url }
}
