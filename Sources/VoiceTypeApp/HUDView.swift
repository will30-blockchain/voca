import SwiftUI
import VoiceTypeCore

/// Floating bottom pill, inspired by Typeless: live waveform in the middle,
/// cancel (✗) on the left, confirm (✓) on the right.
struct HUDView: View {
    @ObservedObject var engine: VoiceTypeEngine
    @ObservedObject var recorder: AudioRecorder
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            cancelButton
            Waveform(level: recorder.level, color: accentColor, isLive: isRecording)
                .frame(height: 28)
            confirmButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DesignTokens.Color.border)
        )
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
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
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(DesignTokens.Color.surfaceElevated))
                .overlay(Circle().stroke(DesignTokens.Color.border))
        }
        .buttonStyle(.plain)
        .help("Cancel — discard this recording")
        .disabled(!isRecording)
        .opacity(isRecording ? 1 : 0.35)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Image(systemName: stateGlyph)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(accentColor))
        }
        .buttonStyle(.plain)
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

/// Animated bar-waveform driven by the recorder's live RMS level. Each bar
/// holds a delayed sample so the cluster looks like a rolling waveform.
struct Waveform: View {
    let level: Float
    let color: Color
    let isLive: Bool

    @State private var history: [Float] = Array(repeating: 0, count: 22)
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(0..<history.count, id: \.self) { i in
                    let v = max(0.06, history[i])
                    Capsule()
                        .fill(color.opacity(isLive ? 0.9 : 0.35))
                        .frame(width: 3, height: max(3, CGFloat(v) * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: history)
        }
        .onAppear { start() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: isLive) { _, _ in /* keep ticking */ }
    }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 18.0, repeats: true) { _ in
            var next = history
            next.removeFirst()
            // Light jitter so the waveform looks alive even on flat input.
            let jitter = Float.random(in: -0.04...0.04)
            next.append(min(1, max(0, (isLive ? level : 0) + jitter)))
            history = next
        }
    }
}
