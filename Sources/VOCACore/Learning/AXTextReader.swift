import Foundation
import ApplicationServices

/// Reads the contents of the currently-focused text element via
/// macOS Accessibility API. Requires Accessibility permission (already
/// requested for hotkey + paste injection).
public enum AXTextReader {
    /// Lightweight handle to a focused text field — we hold the AXUIElement
    /// reference so we can re-read it after the user edits.
    public struct Snapshot: @unchecked Sendable {
        public let element: AXUIElement
        public let valueAtPaste: String
        public let capturedAt: Date
    }

    /// Best-effort: grab the focused element + its current value. Returns
    /// nil if no text element is focused, AX is unavailable, or the value
    /// isn't a string.
    public static func snapshotFocusedField() -> Snapshot? {
        guard let element = focusedTextElement() else { return nil }
        let value = readValue(element) ?? ""
        return Snapshot(element: element, valueAtPaste: value, capturedAt: Date())
    }

    /// Re-read the same element's value. Returns nil if the element is no
    /// longer valid (window closed, app quit, sheet dismissed).
    public static func currentValue(from snapshot: Snapshot) -> String? {
        readValue(snapshot.element)
    }

    // MARK: - Implementation

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

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success, let elementRef = focused else {
            return nil
        }
        return (elementRef as! AXUIElement)
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
