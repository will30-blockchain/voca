import Foundation

/// Returns `~/Library/Application Support/VOCA/`, creating it if missing,
/// and performing a one-time migration from the project's old name
/// ("VoiceType") if that legacy folder is present.
///
/// Every persistence type (SettingsStore, PersonalMemory, UserDictionary,
/// TranscriptHistory, LogStore) goes through this so the migration runs
/// exactly once on first access.
public enum SupportDirectory {
    public static let folderName = "VOCA"
    private static let legacyFolderName = "VoiceType"

    /// Lazily-resolved support directory URL.
    public static let url: URL = {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let target = base.appendingPathComponent(folderName, isDirectory: true)
        let legacy = base.appendingPathComponent(legacyFolderName, isDirectory: true)

        // Migrate legacy data if the new folder doesn't exist yet but the
        // old one does. Move, don't copy — keeps a single source of truth
        // and frees the old name.
        if !fm.fileExists(atPath: target.path), fm.fileExists(atPath: legacy.path) {
            do {
                try fm.moveItem(at: legacy, to: target)
            } catch {
                // Migration failure isn't fatal; fall through to creating a
                // fresh VOCA folder. User keeps their old data under the
                // legacy name and can rename it manually if they care.
            }
        }

        if !fm.fileExists(atPath: target.path) {
            try? fm.createDirectory(at: target, withIntermediateDirectories: true)
        }
        return target
    }()

    /// Convenience for `~/Library/Application Support/VOCA/<name>`.
    public static func file(_ name: String) -> URL {
        url.appendingPathComponent(name)
    }
}
