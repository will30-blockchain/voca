import Foundation
import AppKit
import Carbon.HIToolbox

/// Injects text at the user's current insertion point. Two strategies:
///   - paste: copy to pasteboard, synthesize ⌘V, restore pasteboard.
///   - typed: synthesize each character via CGEvent unicode strings.
///
/// Both require Accessibility permission to deliver synthesized events.
@MainActor
public final class TextInjector {
    public init() {}

    public func inject(_ text: String, method: AppSettings.InjectionMethod) async throws {
        guard !text.isEmpty else { return }
        switch method {
        case .paste: try await paste(text)
        case .typed: try typed(text)
        }
    }

    private func paste(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        let oldItems = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writeChangeCount = pasteboard.changeCount

        // Yield briefly so the foreground app sees the new pasteboard before
        // ⌘V fires. Cooperative await — does not block the main thread.
        try? await Task.sleep(nanoseconds: 30_000_000)
        synthesizeCommandV()

        // Restore pasteboard after a short delay so the paste actually consumes
        // our value first. Guard against clobbering a *newer* clipboard write
        // (e.g., user does another paste, or we kick off a second dictation).
        Task { [oldItems, writeChangeCount] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                guard pasteboard.changeCount == writeChangeCount else { return }
                restorePasteboard(pasteboard, items: oldItems)
            }
        }
    }

    private func typed(_ text: String) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        for character in text {
            let s = String(character)
            let utf16 = Array(s.utf16)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { continue }
            guard let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            utf16.withUnsafeBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
                    up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
                }
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func synthesizeCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09 // kVK_ANSI_V
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboard(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        var snapshot: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pb.pasteboardItems ?? [] {
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            snapshot.append(dict)
        }
        return snapshot
    }

    private func restorePasteboard(_ pb: NSPasteboard, items: [[NSPasteboard.PasteboardType: Data]]) {
        pb.clearContents()
        for raw in items {
            let item = NSPasteboardItem()
            for (type, data) in raw {
                item.setData(data, forType: type)
            }
            pb.writeObjects([item])
        }
    }
}
