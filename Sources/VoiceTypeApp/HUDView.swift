import SwiftUI
import VoiceTypeCore

struct HUDView: View {
    @ObservedObject var engine: VoiceTypeEngine
    @State private var pulse: CGFloat = 0.6

    var body: some View {
        HStack(spacing: 14) {
            indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Font.title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(DesignTokens.Font.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.Color.border, lineWidth: 1)
        )
        .padding(8)
        .onAppear { startPulse() }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = 1.0
        }
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 42, height: 42)
                .scaleEffect(isLive ? pulse : 1)
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
        }
    }

    private var isLive: Bool {
        switch engine.state {
        case .recording, .processing: return true
        default: return false
        }
    }

    private var color: Color {
        switch engine.state {
        case .recording(.translate): return DesignTokens.Color.translate
        case .recording(.transcribe): return DesignTokens.Color.recording
        case .processing(let mode, _):
            return mode == .translate ? DesignTokens.Color.translate : DesignTokens.Color.recording
        case .error: return .yellow
        default: return .secondary
        }
    }

    private var title: String {
        switch engine.state {
        case .idle: return "VoiceType"
        case .recording(.transcribe): return "Listening"
        case .recording(.translate): return "Translating"
        case .processing(_, let stage): return stage
        case .error: return "Error"
        }
    }

    private var subtitle: String {
        switch engine.state {
        case .idle: return "Right Option to dictate"
        case .recording(.transcribe): return "Release Right Option to send"
        case .recording(.translate): return "Release keys to translate"
        case .processing: return "Working…"
        case .error(let msg): return msg
        }
    }
}
