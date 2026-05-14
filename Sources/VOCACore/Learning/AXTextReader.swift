import Foundation
import AppKit
import ApplicationServices

/// Reads the contents of the currently-focused text element via macOS
/// Accessibility API. Requires Accessibility permission (already requested
/// for hotkey + paste injection).
///
/// SECURITY: This is the spine of the auto-learn-from-corrections feature.
/// It also runs on every paste. Without guards it would happily read back
/// secure text fields (password inputs, password-manager rows, sudo
/// prompts), include those values in the next dictation's STT/LLM
/// prompt, *and* persist them to the dictionary. The guards here are
/// load-bearing — do not relax them.
public enum AXTextReader {
    /// Lightweight handle to a focused text field — we hold the AXUIElement
    /// reference so we can re-read it after the user edits.
    public struct Snapshot: @unchecked Sendable {
        public let element: AXUIElement
        public let valueAtPaste: String
        public let capturedAt: Date
    }

    /// Best-effort: grab the focused element + its current value. Returns
    /// nil for:
    ///   - no focused text element
    ///   - secure text fields (NSSecureTextField → AXSecureTextField subrole)
    ///   - apps in a hardcoded blocklist (password managers, security tools)
    ///   - AX unavailable or value isn't a string
    public static func snapshotFocusedField() -> Snapshot? {
        guard let element = focusedTextElement() else { return nil }
        let value = readValue(element) ?? ""
        return Snapshot(element: element, valueAtPaste: value, capturedAt: Date())
    }

    /// Re-read the same element's value. Returns nil if the element is no
    /// longer valid (window closed, app quit, sheet dismissed) — or, as a
    /// late safety net, if the element became a secure field between
    /// snapshot and now.
    public static func currentValue(from snapshot: Snapshot) -> String? {
        guard !isSecureElement(snapshot.element) else { return nil }
        return readValue(snapshot.element)
    }

    // MARK: - Implementation

    /// Bundle IDs we refuse to read from, ever. Password managers + system
    /// security tools are the obvious targets — values inside their windows
    /// are by definition sensitive and have no business showing up in a
    /// dictionary or LLM prompt.
    private static let blockedBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.1password.1password",
        "com.1password.1password7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
        "com.apple.systempreferences.passwords",
        "org.keepassxc.keepassxc",
        "io.enpass.enpass-desktop",
        "com.nordsecurity.nordpass"
    ]

    private static func focusedTextElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success, let appRef = focusedApp else {
            return nil
        }
        let appElement = appRef as! AXUIElement

        // Reject blocked apps before reading anything.
        if let bundleID = bundleID(of: appElement),
           blockedBundleIDs.contains(bundleID) {
            return nil
        }

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success, let elementRef = focused else {
            return nil
        }
        let element = elementRef as! AXUIElement

        // Reject secure text fields (password inputs).
        if isSecureElement(element) { return nil }

        return element
    }

    /// True if the element is a secure text input. macOS does NOT
    /// automatically block AXUIElementCopyAttributeValue on secure fields
    /// for clients that hold Accessibility permission — the protection is
    /// opt-in by the reader. Checks both `kAXSubroleAttribute` and the
    /// (less common but seen) variant `kAXRoleAttribute == AXSecureTextField`.
    private static func isSecureElement(_ element: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let s = subrole as? String,
           s == "AXSecureTextField" {
            return true
        }
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let r = role as? String,
           r == "AXSecureTextField" {
            return true
        }
        return false
    }

    /// Resolve the bundle identifier of the AX-focused application by
    /// matching its PID against NSRunningApplication. Best-effort — returns
    /// nil if anything fails; callers treat nil as "not in blocklist".
    private static func bundleID(of appElement: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(appElement, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private static func readValue(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard err == .success, let value else { return nil }
        if let s = value as? String { return s }
        // Some elements (NSTextView) expose NSAttributedString here.
        if let attr = value as? NSAttributedString { return attr.string }
        return nil
    }
}
