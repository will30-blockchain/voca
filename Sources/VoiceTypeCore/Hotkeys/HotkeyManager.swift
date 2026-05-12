import Foundation
import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Detects global modifier hold patterns:
///   - Right Option held alone → transcribe mode
///   - Right Option + Right Shift held together → translate mode
///
/// Reliability hinges on inspecting the *device-dependent* bits of
/// `NSEvent.ModifierFlags` (the bottom 16 bits of the raw value), because
/// the device-independent `.option` / `.shift` flags don't distinguish
/// left versus right modifier keys.
@MainActor
public final class HotkeyManager {
    public var onBegin: ((DictationMode) -> Void)?
    public var onEnd: ((DictationMode) -> Void)?
    public var onCancel: (() -> Void)?

    // Device-dependent bit masks (see IOLLEvent.h / NX_DEVICE…KEYMASK).
    private static let rightOptionBit: UInt = 0x40
    private static let rightShiftBit: UInt  = 0x04

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// The mode currently signaled to listeners.
    private var activeMode: DictationMode?
    /// Pending begin work that we delay slightly to filter out accidental
    /// Option-key brushes (Option+E for "é" etc.). Cancelled on early release.
    private var pendingBegin: DispatchWorkItem?
    /// Minimum hold duration before we commit to a `begin`. Tuned to be
    /// shorter than any one-shot dead-key composition the user would do.
    public var holdDelay: TimeInterval = 0.18

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
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = mgr.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            let rawFlags = UInt(event.flags.rawValue)
            DispatchQueue.main.async { mgr.evaluate(rawFlags: rawFlags) }
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

        let desired: DictationMode?
        if rightOption && rightShift {
            desired = .translate
        } else if rightOption {
            desired = .transcribe
        } else {
            desired = nil
        }

        if desired == activeMode && pendingBegin == nil { return }

        // If the user lifts before the hold delay elapses, cancel the pending
        // begin so brief Option taps don't trigger a recording.
        if desired == nil {
            pendingBegin?.cancel()
            pendingBegin = nil
            if let active = activeMode {
                activeMode = nil
                onEnd?(active)
            }
            return
        }

        if let next = desired {
            if let prev = activeMode, prev != next {
                // User shifted modes mid-press (e.g. added Right Shift).
                onCancel?()
                activeMode = nil
            }

            // Already engaged? Nothing to do.
            if activeMode == next { return }

            // Schedule the begin after the hold delay so a quick Option tap
            // (used for accented characters) doesn't trip dictation.
            pendingBegin?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingBegin = nil
                if self.activeMode == nil {
                    self.activeMode = next
                    self.onBegin?(next)
                }
            }
            pendingBegin = item
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: item)
        }
    }
}
