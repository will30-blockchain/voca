import AppKit
import SwiftUI
import Combine
import VOCACore

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
            slideOut()
            return
        }
        slideIn()
        // Auto-dismiss after 5 seconds.
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.learner.clearLatest()
            }
        }
    }

    /// Slide in from above the resting position while fading 0 → 1.
    private func slideIn() {
        let target = restingOrigin()
        let startOrigin = NSPoint(x: target.x, y: target.y + 18)

        window.alphaValue = 0
        var startFrame = window.frame
        startFrame.origin = startOrigin
        window.setFrame(startFrame, display: false)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.85, 0.32, 1.02)
            window.animator().alphaValue = 1
            var endFrame = window.frame
            endFrame.origin = target
            window.animator().setFrame(endFrame, display: true)
        }
    }

    private func slideOut() {
        let endY = window.frame.origin.y + 14
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            var endFrame = window.frame
            endFrame.origin.y = endY
            window.animator().setFrame(endFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
        })
    }

    private func restingOrigin() -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return .zero }
        let visible = screen.visibleFrame
        let size = window.frame.size
        return NSPoint(
            x: visible.maxX - size.width - 16,
            y: visible.maxY - size.height - 16
        )
    }
}

private struct ToastView: View {
    @ObservedObject var learner: CorrectionLearner
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(DesignTokens.Color.accentTint))

            VStack(alignment: .leading, spacing: 3) {
                // Term first — it's the thing the user actually cares about
                // and reads as a headline. "added to dictionary" is the soft
                // explanation underneath.
                Text(learner.latest?.term ?? "")
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 8) {
                    Text("added to dictionary")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                    Button("Undo", action: onUndo)
                        .buttonStyle(.plain)
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.accent)
                }
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
            .help("Dismiss")
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
        .padding(8)
    }
}
