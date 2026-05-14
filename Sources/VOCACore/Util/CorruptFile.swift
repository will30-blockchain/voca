import Foundation

/// When a persistence layer fails to decode its JSON file, we don't want
/// to silently overwrite it with defaults — that would let any byte-level
/// corruption nuke the user's dictionary / settings / memory permanently.
/// Instead, rename the bad file to `<name>.corrupt-<timestamp>` so the
/// user can recover by hand if they care.
enum CorruptFile {
    static func quarantine(_ url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")
        try? fm.moveItem(at: url, to: backup)
    }
}
