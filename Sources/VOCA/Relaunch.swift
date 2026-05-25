import AppKit
import Foundation

/// Quits VOCA and immediately launches a fresh instance of the same bundle.
///
/// Used after the user grants Accessibility — macOS only re-reads AX trust
/// at process start, so a granted-but-not-restarted VOCA still can't see
/// global events from other apps.
@MainActor
enum Relaunch {
    static func now() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        // Give launch services a beat to register the new process before we
        // terminate the old one; otherwise the new instance can race the
        // app's exit and fail to come up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}
