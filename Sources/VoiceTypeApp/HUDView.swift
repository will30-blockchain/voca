import SwiftUI
import VoiceTypeCore

/// Floating recording pill at the bottom of the screen.
/// Cancel (✗) on the left · live waveform · confirm (✓) on the right.
///
/// Visual language: SuperCard "Professional Warmth" — warm light glass on
/// off-white paper, single hairline border, soft lift shadow. The pill reads
/// as a small card resting on the desktop, not as a HUD floating in dark.
struct HUDView: View {
    @ObservedObject var engine: VoiceTypeEngine
    @ObservedObject var recorder: AudioRecorder
    var onCancel: () -> Void
    var onConfirm: () -> Void
    var onRetry: () -> Void

    var body: some View {
        // Two layouts: the "running" pill (cancel · waveform · confirm) and
        // the "error" pill (dismiss · message · retry). Errors get a wider
        // pill so the message reads cleanly.
        Group {
            if isError {
                errorPill
            } else {
                runningPill
            }
        }
        .padding(10)
    }

    private var runningPill: some View {
        HStack(spacing: DesignTokens.Space.sm) {
            cancelButton
            Waveform(recorder: recorder, color: accentColor, isLive: isRecording)
                .frame(height: 28)
                .frame(maxWidth: .infinity)
            confirmButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 360)
        .background(pillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .strokeBorder(DesignTokens.Color.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 6)
    }

    private var errorPill: some View {
        HStack(spacing: DesignTokens.Space.sm) {
            HUDCircleButton(
                systemImage: "xmark",
                fill: DesignTokens.Color.surfaceSunken,
                glyphColor: DesignTokens.Color.textSecondary,
                action: onCancel
            )
            .help("Dismiss")

            VStack(alignment: .leading, spacing: 1) {
                Text("Couldn't transcribe")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.danger)
                    .lineLimit(1)
                Text(errorMessage)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if engine.canRetry {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(DesignTokens.Typography.captionEmphasis)
                        .padding(.horizontal, DesignTokens.Space.sm)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(
                            Capsule().fill(DesignTokens.Color.danger)
                        )
                }
                .buttonStyle(.plain)
                .help("Re-run transcription on the same recording")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 400)
        .background(errorPillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .strokeBorder(DesignTokens.Color.danger.opacity(0.35), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 6)
    }

    private var errorMessage: String {
        if case .error(let m) = engine.state { return m }
        return ""
    }

    // MARK: - Background

    /// Warm light glass: a translucent material layered over a creamy off-white
    /// tinted by the active accent. Keeps the pill reading as paper, not chrome.
    private var pillBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(DesignTokens.Color.surface)
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(accentTintColor.opacity(0.08))
        }
    }

    /// Error pill uses a softer warning tint instead of the recording accent
    /// so the colour itself signals "something needs attention".
    private var errorPillBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(DesignTokens.Color.surface)
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(DesignTokens.Color.danger.opacity(0.06))
        }
    }

    private var isError: Bool {
        if case .error = engine.state { return true }
        return false
    }

    // MARK: - State helpers

    private var isRecording: Bool {
        if case .recording = engine.state { return true }
        return false
    }

    /// Foreground accent — drives confirm fill, waveform tint, and the
    /// surrounding warm wash. Falls back to neutral text gray when idle.
    private var accentColor: Color {
        switch engine.state {
        case .recording(.translate), .processing(.translate, _):
            return DesignTokens.Color.translate
        case .recording(.transcribe), .processing(.transcribe, _):
            return DesignTokens.Color.recording
        case .error:
            return DesignTokens.Color.warning
        default:
            return DesignTokens.Color.textTertiary
        }
    }

    /// Accent used to tint the pill itself — softer fallback so the idle pill
    /// stays neutral warm rather than gray.
    private var accentTintColor: Color {
        switch engine.state {
        case .recording(.translate), .processing(.translate, _):
            return DesignTokens.Color.translate
        case .recording(.transcribe), .processing(.transcribe, _):
            return DesignTokens.Color.recording
        case .error:
            return DesignTokens.Color.warning
        default:
            return DesignTokens.Color.accentSoft
        }
    }

    // MARK: - Buttons

    private var cancelButton: some View {
        HUDCircleButton(
            systemImage: "xmark",
            fill: DesignTokens.Color.surfaceSunken,
            glyphColor: DesignTokens.Color.textSecondary,
            action: onCancel
        )
        .help("Cancel — discard this recording")
        .disabled(!isRecording)
        .opacity(isRecording ? 1 : 0.45)
    }

    private var confirmButton: some View {
        HUDCircleButton(
            systemImage: stateGlyph,
            fill: accentColor,
            glyphColor: .white,
            action: onConfirm
        )
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

// MARK: - HUDCircleButton

/// Solid-circle button used for both cancel and confirm. No stroke ring —
/// the pill itself owns the only border in this composition.
private struct HUDCircleButton: View {
    let systemImage: String
    let fill: Color
    let glyphColor: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(glyphColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(fill)
                )
                .brightness(isHovering ? 0.04 : 0)
                .scaleEffect(isHovering ? 1.06 : 1.0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.snappy, value: isHovering)
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
        // sqrt amplifies small signals — speech registers visibly even when RMS
        // is ~0.1, which is what makes the meter look "alive".
        let amp = sqrt(max(0, min(1, raw)))
        // Bell-curve falloff at the edges so the cluster looks meter-shaped.
        let t = Double(i) / Double(max(1, total - 1))
        let edge = CGFloat(1 - pow(2 * t - 1, 2) * 0.35)
        let h2 = max(minHeight, CGFloat(amp) * height * edge)
        return Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(isLive ? 0.95 : 0.35),
                        color.opacity(isLive ? 0.65 : 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: barWidth, height: h2)
            .animation(.easeOut(duration: 0.08), value: h2)
    }
}
