import AppKit
import VOCACore

/// Builds the system menu bar. We don't ship visible menu titles for
/// every feature (VOCA is mostly menu-bar-driven), but we DO need a
/// proper Edit menu so Cmd+C / Cmd+V / Cmd+X / Cmd+A / Cmd+Z work
/// inside text fields — `SecureField` and `TextField` rely on the
/// responder chain reaching menu items with those key equivalents.
///
/// Without this, pasting into the Providers API key fields silently
/// fails because no responder handles the keystroke.
@MainActor
enum MainMenu {
    static func install(language: AppLanguage) -> NSMenu {
        let strings = MenuStrings(language: language)
        let menu = NSMenu()

        // App menu — first slot, conventionally the app name.
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu(title: strings.appName)
        appMenu.addItem(withTitle: strings.about, action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        let hide = appMenu.addItem(withTitle: strings.hide,
                                   action: #selector(NSApplication.hide(_:)),
                                   keyEquivalent: "h")
        hide.target = NSApp
        let hideOthers = appMenu.addItem(withTitle: strings.hideOthers,
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        let showAll = appMenu.addItem(withTitle: strings.showAll,
                                      action: #selector(NSApplication.unhideAllApplications(_:)),
                                      keyEquivalent: "")
        showAll.target = NSApp
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: strings.quit,
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q")
        quit.target = NSApp
        appItem.submenu = appMenu

        // Edit menu — the critical one for Cmd+C/V/X/A in text fields.
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: strings.edit)
        let undo = editMenu.addItem(withTitle: strings.undo,
                                    action: Selector(("undo:")),
                                    keyEquivalent: "z")
        undo.target = nil // responder chain
        let redo = editMenu.addItem(withTitle: strings.redo,
                                    action: Selector(("redo:")),
                                    keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.target = nil
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: strings.cut,
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: strings.copy,
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: strings.paste,
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: strings.delete,
                         action: #selector(NSText.delete(_:)),
                         keyEquivalent: "")
        editMenu.addItem(withTitle: strings.selectAll,
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editItem.submenu = editMenu

        // Window menu — standard, gives Minimise + Zoom + window cycling
        // for free, and macOS will populate the open-window list.
        let windowItem = NSMenuItem()
        menu.addItem(windowItem)
        let windowMenu = NSMenu(title: strings.window)
        windowMenu.addItem(withTitle: strings.minimize,
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: strings.zoom,
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        return menu
    }
}

/// Translated menu titles — Cmd+C / 複製 etc. Picked from the current
/// uiLanguage at app launch. The menu bar doesn't live-update on
/// language changes; users get the right strings on next launch.
private struct MenuStrings {
    let appName: String
    let about: String
    let hide: String
    let hideOthers: String
    let showAll: String
    let quit: String
    let edit: String
    let undo: String
    let redo: String
    let cut: String
    let copy: String
    let paste: String
    let delete: String
    let selectAll: String
    let window: String
    let minimize: String
    let zoom: String

    init(language: AppLanguage) {
        switch language.effective {
        case .traditionalChinese:
            self.appName = "VOCA"
            self.about = "關於 VOCA"
            self.hide = "隱藏 VOCA"
            self.hideOthers = "隱藏其他"
            self.showAll = "顯示全部"
            self.quit = "結束 VOCA"
            self.edit = "編輯"
            self.undo = "復原"
            self.redo = "重做"
            self.cut = "剪下"
            self.copy = "複製"
            self.paste = "貼上"
            self.delete = "刪除"
            self.selectAll = "全選"
            self.window = "視窗"
            self.minimize = "縮到最小"
            self.zoom = "縮放"
        default:
            self.appName = "VOCA"
            self.about = "About VOCA"
            self.hide = "Hide VOCA"
            self.hideOthers = "Hide Others"
            self.showAll = "Show All"
            self.quit = "Quit VOCA"
            self.edit = "Edit"
            self.undo = "Undo"
            self.redo = "Redo"
            self.cut = "Cut"
            self.copy = "Copy"
            self.paste = "Paste"
            self.delete = "Delete"
            self.selectAll = "Select All"
            self.window = "Window"
            self.minimize = "Minimize"
            self.zoom = "Zoom"
        }
    }
}
