import Foundation

/// Counters that make the auto-learn pipeline observable. Review flagged that
/// without measurement we're flying blind: the biggest unknown is the CAPTURE
/// RATE — how often we can even read back the field the user edited (native
/// AppKit fields work; many Electron/web/terminal fields don't). These
/// counters expose that, plus how many candidates are held vs promoted.
///
/// Pure and Codable — unit-testable. `LearningMetricsStore` persists it.
public struct LearningMetrics: Codable, Sendable, Equatable {
    /// recordPaste() was called — a dictation was pasted and we tried to
    /// arm the edit watcher.
    public var captureAttempts: Int = 0
    /// The focused field was AX-readable and snapshotted. The ratio
    /// successes/attempts is the capture rate.
    public var captureSuccesses: Int = 0
    /// A review actually ran a diff against an edited field.
    public var reviewsFired: Int = 0
    /// A candidate was found but held by the confidence gate (sub-threshold).
    public var candidatesHeld: Int = 0
    /// A candidate cleared the gate and was persisted to the dictionary.
    public var termsPromoted: Int = 0

    public init() {}

    /// Capture rate in [0, 1]; 0 when nothing has been attempted yet.
    public var captureRate: Double {
        captureAttempts == 0 ? 0 : Double(captureSuccesses) / Double(captureAttempts)
    }

    /// Short human-readable one-liner for logs / the dashboard.
    public var summary: String {
        let pct = Int((captureRate * 100).rounded())
        return "capture \(captureSuccesses)/\(captureAttempts) (\(pct)%), "
            + "promoted \(termsPromoted), held \(candidatesHeld)"
    }
}

/// Thin disk-persistence wrapper around `LearningMetrics`, mirroring the
/// other stores. Mutations are cheap and persisted immediately.
@MainActor
public final class LearningMetricsStore {
    public private(set) var metrics: LearningMetrics
    private let url: URL

    public nonisolated init() {
        self.url = SupportDirectory.file("learn_metrics.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(LearningMetrics.self, from: data) {
            self.metrics = decoded
        } else {
            self.metrics = LearningMetrics()
        }
    }

    public func recordCaptureAttempt(succeeded: Bool) {
        metrics.captureAttempts += 1
        if succeeded { metrics.captureSuccesses += 1 }
        save()
    }

    public func recordReviewFired() {
        metrics.reviewsFired += 1
        save()
    }

    public func recordHeld() {
        metrics.candidatesHeld += 1
        save()
    }

    public func recordPromoted() {
        metrics.termsPromoted += 1
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        try? SupportDirectory.writeSecurely(data, to: url)
    }
}
