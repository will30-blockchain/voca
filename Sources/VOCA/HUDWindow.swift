import AppKit
import SwiftUI
import Combine
import VOCACore

@MainActor
final class HUDWindowController {
    private let window: NSPanel
    private let engine: VOCAEngine
    private var cancellables: Set<AnyCancellable> = []
    private let settingsStore: SettingsStore
    private let hostView: NSHostingView<AnyView>

    init(engine: VOCAEngine, settingsStore: SettingsStore) {
        self.engine = engine
        self.settingsStore = settingsStore

        let rect = NSRect(x: 0, y: 0, width: 420, height: 72)
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // Let SwiftUI draw the shadow under the rounded pill — the NSPanel's
        // own shadow is rectangular and would peek out around the pill edges
        // as a second visible border.
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // Allow clicks on the cancel/confirm buttons; the rest of the pill
        // doesn't react to clicks because it's just a Text/Waveform.
        panel.ignoresMouseEvents = false

        let hudRoot = HUDView(
            engine: engine,
            recorder: engine.recorder,
            onCancel: { Task { await engine.cancelRecording() } },
            onConfirm: { Task { await engine.endRecording() } },
            onRetry: { Task { await engine.retryLastRecording() } }
        )
        .environmentObject(settingsStore)
        let host = NSHostingView(rootView: AnyView(hudRoot))
        host.frame = rect
        panel.contentView = host
        self.hostView = host
        self.window = panel

        engine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.apply(state: state)
            }
            .store(in: &cancellables)
    }

    private func apply(state: EngineState) {
        guard settingsStore.settings.showHUD else {
            window.orderOut(nil)
            return
        }
        switch state {
        case .idle:
            slideOut()
        default:
            let alreadyVisible = window.isVisible && window.alphaValue > 0.1
            if alreadyVisible {
                // The pill is changing layout (e.g. running → error). Just
                // reposition smoothly without a fresh slide-in.
                reposition(animated: true)
            } else {
                slideIn()
            }
        }
    }

    /// Animates the pill in from ~20 pt below the final resting spot while
    /// fading alpha 0 → 1. Easing is a slight overshoot so it feels alive,
    /// not mechanical.
    private func slideIn() {
        let target = restingOrigin()
        let startOrigin = NSPoint(x: target.x, y: target.y - 20)

        window.alphaValue = 0
        var startFrame = window.frame
        startFrame.origin = startOrigin
        window.setFrame(startFrame, display: false)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.30
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.85, 0.32, 1.02)
            window.animator().alphaValue = 1.0
            var endFrame = window.frame
            endFrame.origin = target
            window.animator().setFrame(endFrame, display: true)
        }
    }

    /// Inverse of slideIn — fade + slide down a few points and orderOut.
    private func slideOut() {
        let endY = window.frame.origin.y - 14
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

    /// Used when the pill is already visible but needs to adapt its size or
    /// position (e.g. running pill 360 pt wide → error pill 420 pt wide).
    private func reposition(animated: Bool) {
        let target = restingOrigin()
        var endFrame = window.frame
        endFrame.origin = target
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                window.animator().setFrame(endFrame, display: true)
            }
        } else {
            window.setFrame(endFrame, display: true)
        }
    }

    private func restingOrigin() -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return .zero }
        let frame = screen.visibleFrame
        let size = window.frame.size
        return NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 60
        )
    }
}
