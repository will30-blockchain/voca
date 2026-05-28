import Foundation
import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Tap-toggle global hotkey:
///   - Tap **Right Option** → toggle transcribe mode (start; tap again to stop).
///   - Tap **Right Option + Right Shift** → toggle translate mode. Either
///     order works: press Option first then add Shift before releasing, or
///     hold Shift first and tap Option. As long as both were down at any
///     point during the Option tap window, the tap fires as translate.
///
/// A "tap" is a key-down followed by a key-up within `tapWindow` (default
/// 0.5 s). Anything longer is treated as a hold (for accent input like
/// Option+E → "é") and ignored, so the dictation flow doesn't clash with
/// macOS dead-key composition.
///
/// State machine fires:
///   - `onToggle(.transcribe)` / `onToggle(.translate)` for the user's tap.
///
/// The controller (VOCAEngine) is the source of truth for whether a
/// recording is currently active; this class only emits toggle intents.
@MainActor
public final class HotkeyManager {
    public var onToggle: ((DictationMode) -> Void)?
    /// Fired when the user presses Escape. Wired to `engine.cancelRecording()`
    /// so the user can bail out of an active dictation without paste.
    public var onEscape: (() -> Void)?

    // Device-dependent modifier bits (bottom 16 bits of NSEvent.ModifierFlags).
    private static let rightOptionBit: UInt = 0x40
    private static let rightShiftBit: UInt  = 0x04
    private static let escapeKeyCode: Int64 = 53 // kVK_Escape

    /// Max duration of a key press that still counts as a "tap".
    public var tapWindow: TimeInterval = 0.5

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Timestamp when Right Option last went down, or nil if it's up.
    private var rightOptionDownAt: TimeInterval?
    /// Was Right Shift held at the moment Right Option went down?
    private var translateLatched = false

    /// Last computed states so we can detect transitions.
    private var lastRightOption = false
    private var lastRightShift = false

    public init() {}

    public func start() {
        if tap != nil { return }
        installEventTap()
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    private func installEventTap() {
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = mgr.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            // Ignore synthesized events. A hostile app posting flag-changed
            // events with CGEventCreate could otherwise induce phantom
            // dictations (mic light flips on, recording uploads to a cloud
            // STT). HID events have non-zero hardware source IDs; synthetic
            // events post with the source set to "combinedSessionState" /
            // "hidSystemState" but with `eventTargetUnixProcessID` of the
            // poster — easiest reliable signal is the `kCGEventSourceStateID`
            // field on the event being negative or one of the synthetic IDs.
            let source = event.getIntegerValueField(.eventSourceStateID)
            let isSynthetic = source != 1   // 1 == kCGEventSourceStateHIDSystemState
            if isSynthetic { return Unmanaged.passUnretained(event) }

            switch type {
            case .flagsChanged:
                let rawFlags = UInt(event.flags.rawValue)
                DispatchQueue.main.async { mgr.evaluate(rawFlags: rawFlags) }
            case .keyDown:
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == HotkeyManager.escapeKeyCode {
                    DispatchQueue.main.async { mgr.onEscape?() }
                }
            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLog.hotkey.error("Failed to create CGEvent tap — Accessibility permission likely missing.")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.runLoopSource = source
        AppLog.hotkey.info("CGEvent tap installed.")
    }

    private func evaluate(rawFlags: UInt) {
        let rightOption = (rawFlags & Self.rightOptionBit) != 0
        let rightShift = (rawFlags & Self.rightShiftBit) != 0
        defer {
            lastRightOption = rightOption
            lastRightShift = rightShift
        }

        // Right Option transition is the only thing that decides a tap.
        if rightOption && !lastRightOption {
            // Key down. Latch translate if Shift was already held when
            // Option went down.
            rightOptionDownAt = Date().timeIntervalSince1970
            translateLatched = rightShift
        } else if rightOption && rightShift && !translateLatched {
            // Right Option is still held and Right Shift just came on
            // (the "Option first, then Shift" gesture). Latch translate
            // so the upcoming Option key-up fires as translate even if
            // Shift gets released before Option does.
            translateLatched = true
        } else if !rightOption && lastRightOption {
            // Key up.
            defer { rightOptionDownAt = nil; translateLatched = false }
            guard let downAt = rightOptionDownAt else { return }
            let elapsed = Date().timeIntervalSince1970 - downAt
            guard elapsed <= tapWindow else {
                AppLog.hotkey.debug("Ignored long hold of Right Option (\(elapsed, format: .fixed(precision: 2)) s)")
                return
            }
            let mode: DictationMode = (translateLatched || rightShift) ? .translate : .transcribe
            onToggle?(mode)
        }

        // Once `translateLatched` is true for a given Option hold, it
        // stays true until the next Option key-up — we never down-grade
        // a translate intent back to transcribe just because Shift went
        // up early.
    }
}
