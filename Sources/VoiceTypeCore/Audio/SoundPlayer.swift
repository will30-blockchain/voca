import AppKit

/// Plays the small UI cue sounds — start, stop, error. Uses macOS system
/// sounds (`/System/Library/Sounds`) so they always exist, sound consistent
/// with the rest of the OS, and don't require shipping audio assets.
///
/// "Tink" is a quick soft tap — used for start to acknowledge the press
/// without startling the user. "Glass" is a delicate two-tone chime — used
/// for stop, matching the user's request for an elevator-ding feel.
@MainActor
public final class SoundPlayer {
    public init() {}

    public func playStart() {
        play("Tink", volume: 0.4)
    }

    public func playStop() {
        play("Glass", volume: 0.35)
    }

    public func playError() {
        play("Funk", volume: 0.4)
    }

    private func play(_ name: String, volume: Float) {
        // NSSound caches by name; safe to construct each call.
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}
