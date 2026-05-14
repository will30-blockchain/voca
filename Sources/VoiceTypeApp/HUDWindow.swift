import AppKit
import SwiftUI
import Combine
import VoiceTypeCore

@MainActor
final class HUDWindowController {
    private let window: NSPanel
    private let engine: VoiceTypeEngine
    private var cancellables: Set<AnyCancellable> = []
    private let settingsStore: SettingsStore

    init(engine: VoiceTypeEngine, settingsStore: SettingsStore) {
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // Allow clicks on the cancel/confirm buttons; the rest of the pill
        // doesn't react to clicks because it's just a Text/Waveform.
        panel.ignoresMouseEvents = false

        let host = NSHostingView(rootView: HUDView(
            engine: engine,
            recorder: engine.recorder,
            onCancel: { Task { await engine.cancelRecording() } },
            onConfirm: { Task { await engine.endRecording() } },
            onRetry: { Task { await engine.retryLastRecording() } }
        ))
        host.frame = rect
        panel.contentView = host
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
            fadeOut()
        default:
            placeNearMouse()
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                window.animator().alphaValue = 1.0
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

    private func placeNearMouse() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 60
        )
        window.setFrameOrigin(origin)
    }
}
