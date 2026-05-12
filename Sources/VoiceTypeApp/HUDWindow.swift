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

        let rect = NSRect(x: 0, y: 0, width: 280, height: 84)
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
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true

        let host = NSHostingView(rootView: HUDView(engine: engine))
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
            y: frame.minY + 28
        )
        window.setFrameOrigin(origin)
    }
}
