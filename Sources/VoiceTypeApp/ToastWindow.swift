import AppKit
import SwiftUI
import Combine
import VoiceTypeCore

/// Top-right corner toast that announces auto-learned dictionary terms.
/// Inspired by Typeless's "Added 'Anthropic' to your dictionary" prompt.
/// Fades in when `learner.latest` changes, auto-dismisses after 5 s, or
/// stays around if the user hovers. Includes an Undo button.
@MainActor
final class ToastWindowController {
    private let window: NSPanel
    private let learner: CorrectionLearner
    private var cancellables: Set<AnyCancellable> = []
    private var dismissTask: Task<Void, Never>?

    init(learner: CorrectionLearner) {
        self.learner = learner

        let rect = NSRect(x: 0, y: 0, width: 320, height: 76)
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.alphaValue = 0
        panel.appearance = NSAppearance(named: .aqua)

        let host = NSHostingView(rootView: ToastView(
            learner: learner,
            onUndo: { [weak learner] in
                learner?.undoLatest()
            },
            onDismiss: { [weak learner] in
                learner?.clearLatest()
            }
        ))
        host.frame = rect
        panel.contentView = host
        self.window = panel

        learner.$latest
            .receive(on: RunLoop.main)
            .sink { [weak self] term in
                self?.handle(term: term)
            }
            .store(in: &cancellables)
    }

    private func handle(term: CorrectionLearner.LearnedTerm?) {
        dismissTask?.cancel()
        guard term != nil else {
            fadeOut()
            return
        }
        placeTopRight()
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 1
        }
        // Auto-dismiss after 5 seconds.
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.learner.clearLatest()
            }
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
        })
    }

    private func placeTopRight() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 16,
            y: visible.maxY - size.height - 16
        )
        window.setFrameOrigin(origin)
    }
}

private struct ToastView: View {
    @ObservedObject var learner: CorrectionLearner
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignTokens.Color.accentTint))

            VStack(alignment: .leading, spacing: 2) {
                Text("Added to dictionary")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                Text(learner.latest?.term ?? "")
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                Button("Undo", action: onUndo)
                    .buttonStyle(.plain)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.accent)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Space.md)
        .padding(.vertical, DesignTokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(DesignTokens.Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(DesignTokens.Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 4)
        .padding(8)
    }
}
