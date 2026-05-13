import SwiftUI
import VoiceTypeCore

/// Floating recording pill at the bottom of the screen.
/// Cancel (✗) on the left · live waveform · confirm (✓) on the right.
struct HUDView: View {
    @ObservedObject var engine: VoiceTypeEngine
    @ObservedObject var recorder: AudioRecorder
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            cancelButton
            Waveform(recorder: recorder, color: accentColor, isLive: isRecording)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            confirmButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
        .padding(8)
    }

    private var isRecording: Bool {
        if case .recording = engine.state { return true }
        return false
    }

    private var accentColor: Color {
        switch engine.state {
        case .recording(.translate), .processing(.translate, _): return DesignTokens.Color.translate
        case .recording(.transcribe), .processing(.transcribe, _): return DesignTokens.Color.recording
        case .error: return .yellow
        default: return .secondary
        }
    }

    private var cancelButton: some View {
        PillButton(systemImage: "xmark", filled: false, tint: .primary, action: onCancel)
            .help("Cancel — discard this recording")
            .disabled(!isRecording)
            .opacity(isRecording ? 1 : 0.35)
    }

    private var confirmButton: some View {
        PillButton(systemImage: stateGlyph, filled: true, tint: accentColor, action: onConfirm)
            .help(isRecording ? "Stop and paste" : "Processing…")
            .disabled(!isRecording)
            .opacity(isRecording ? 1 : 0.55)
    }

    private var stateGlyph: String {
        switch engine.state {
        case .recording: return "checkmark"
        case .processing: return "ellipsis"
        case .error: return "exclamationmark"
        default: return "checkmark"
        }
    }
}

private struct PillButton: View {
    let systemImage: String
    let filled: Bool
    let tint: Color
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(filled ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(filled ? tint : Color.primary.opacity(hover ? 0.10 : 0.06))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Waveform

/// Drives the rolling history of RMS samples. Lives in a class because the
/// View struct is recreated on every parent re-render — without a stable
/// reference, the Timer closure captures a stale snapshot of `level` and
/// just feeds zeros forever (the exact symptom: bars don't move).
@MainActor
final class WaveformAnimator: ObservableObject {
    @Published var history: [Float] = Array(repeating: 0, count: 36)
    /// Set every render so the timer sees the live value.
    var isLive: Bool = false

    private weak var recorder: AudioRecorder?
    private var timer: Timer?

    func attach(recorder: AudioRecorder) {
        self.recorder = recorder
    }

    func ensureCapacity(_ size: Int) {
        if history.count != size {
            history = Array(repeating: 0, count: size)
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 28.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let raw = self.recorder?.level ?? 0
                // Slight smoothing so a single noisy frame doesn't make a spike
                // that looks like a glitch.
                let smoothed = self.history.last.map { 0.55 * $0 + 0.45 * raw } ?? raw
                let jitter = Float.random(in: -0.015...0.015)
                let sample = self.isLive ? max(0, min(1, smoothed + jitter)) : max(0, (self.history.last ?? 0) * 0.85)
                var next = self.history
                if !next.isEmpty {
                    next.removeFirst()
                    next.append(sample)
                    self.history = next
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct Waveform: View {
    @ObservedObject var recorder: AudioRecorder
    let color: Color
    let isLive: Bool

    @StateObject private var animator = WaveformAnimator()

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minHeight: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let totalBars = max(8, Int((proxy.size.width + barSpacing) / (barWidth + barSpacing)))
            let h = proxy.size.height
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<totalBars, id: \.self) { i in
                    bar(index: i, total: totalBars, height: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                animator.attach(recorder: recorder)
                animator.ensureCapacity(totalBars)
                animator.isLive = isLive
                animator.start()
            }
            .onChange(of: totalBars) { _, new in animator.ensureCapacity(new) }
            .onChange(of: isLive) { _, new in animator.isLive = new }
            .onDisappear { animator.stop() }
        }
    }

    private func bar(index i: Int, total: Int, height: CGFloat) -> some View {
        // Right-aligned tail of history so the freshest sample sits at the right edge.
        let h = animator.history
        let raw: Float
        if h.isEmpty {
            raw = 0
        } else {
            let offset = h.count - total + i
            raw = offset >= 0 && offset < h.count ? h[offset] : 0
        }
        // Bell-curve falloff at the edges so the cluster looks meter-shaped.
        let t = Double(i) / Double(max(1, total - 1))
        let edge = CGFloat(1 - pow(2 * t - 1, 2) * 0.35)
        let h2 = max(minHeight, CGFloat(raw) * height * edge)
        return Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(isLive ? 0.95 : 0.40), color.opacity(isLive ? 0.55 : 0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: barWidth, height: h2)
            .animation(.easeOut(duration: 0.08), value: h2)
    }
}
