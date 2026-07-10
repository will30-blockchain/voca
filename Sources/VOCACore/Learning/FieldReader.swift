import Foundation
import ApplicationServices

/// Abstraction over "read the focused text field, then re-read it later".
///
/// Extracted so `CorrectionLearner` no longer calls `AXTextReader`'s static
/// AX methods directly — that made the learn/gate logic untestable (AX needs
/// a real focused UI element + Accessibility permission). Production uses
/// `AXFieldReader`; tests inject a scripted fake.
@MainActor
public protocol FieldReader: AnyObject {
    /// Capture the currently-focused text field. `nil` when there is no
    /// readable text element, it's a secure/blocked field, or AX is off.
    func snapshotFocused() -> FieldSnapshot?
    /// Re-read the value of a previously captured field. `nil` when the
    /// element is gone (window closed, focus moved) or became secure.
    func reread(_ snapshot: FieldSnapshot) -> String?
}

/// Opaque capture token. Carries the value at capture time; the concrete
/// reader keeps whatever backing it needs (an `AXUIElement`, or scripted
/// test data) keyed by `id`.
public final class FieldSnapshot: Sendable {
    public let id: UUID
    public let valueAtCapture: String
    public let capturedAt: Date

    public init(id: UUID = UUID(), valueAtCapture: String, capturedAt: Date = Date()) {
        self.id = id
        self.valueAtCapture = valueAtCapture
        self.capturedAt = capturedAt
    }
}

/// Production `FieldReader` backed by `AXTextReader`. Holds the live
/// `AXUIElement` for the one snapshot the learner is currently tracking —
/// the map is reset on every new capture, so it never accumulates.
@MainActor
public final class AXFieldReader: FieldReader {
    private var elements: [UUID: AXUIElement] = [:]

    // nonisolated so it can serve as a default argument for
    // CorrectionLearner.init without tripping actor-isolation checks.
    public nonisolated init() {}

    public func snapshotFocused() -> FieldSnapshot? {
        guard let snap = AXTextReader.snapshotFocusedField() else { return nil }
        let token = FieldSnapshot(valueAtCapture: snap.valueAtPaste, capturedAt: snap.capturedAt)
        // Only ever track the latest capture — no unbounded growth.
        elements = [token.id: snap.element]
        return token
    }

    public func reread(_ snapshot: FieldSnapshot) -> String? {
        guard let element = elements[snapshot.id] else { return nil }
        let axSnap = AXTextReader.Snapshot(
            element: element,
            valueAtPaste: snapshot.valueAtCapture,
            capturedAt: snapshot.capturedAt
        )
        return AXTextReader.currentValue(from: axSnap)
    }
}
