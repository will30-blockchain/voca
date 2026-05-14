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

    /// Lazily-resolved support directory URL. The directory itself is
    /// chmod 0700 so other local accounts on the Mac can't read its
    /// contents.
    public static let url: URL = {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let target = base.appendingPathComponent(folderName, isDirectory: true)
        let legacy = base.appendingPathComponent(legacyFolderName, isDirectory: true)

        // Migrate legacy data if the new folder doesn't exist yet but the
        // old one does AND the old path isn't a symlink (TOCTOU guard).
        if !fm.fileExists(atPath: target.path), fm.fileExists(atPath: legacy.path) {
            let isSymlink = (try? legacy.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            if !isSymlink {
                try? fm.moveItem(at: legacy, to: target)
            }
        }

        if !fm.fileExists(atPath: target.path) {
            try? fm.createDirectory(
                at: target,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else {
            // Re-apply 0700 in case an older build (or the migration above)
            // left the directory at the default 0755.
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: target.path)
        }

        // Tighten any pre-existing data files (older builds wrote them
        // with the default 0644). Run on every launch — cheap, idempotent.
        if let contents = try? fm.contentsOfDirectory(atPath: target.path) {
            for name in contents {
                let path = target.appendingPathComponent(name).path
                try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
        return target
    }()

    /// Convenience for `~/Library/Application Support/VOCA/<name>`.
    public static func file(_ name: String) -> URL {
        url.appendingPathComponent(name)
    }

    /// Write `data` to `url` atomically and then chmod 0600. Helper used
    /// by every persistence store so the on-disk files are owner-only.
    public static func writeSecurely(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
