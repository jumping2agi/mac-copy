import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install a hidden main menu with the standard Edit menu. Although the
        // app runs as an accessory (LSUIElement, no visible menu bar), this
        // menu is required for the system to route ⌘A/C/V/X/Z (and friends) to
        // text fields in the settings window.
        installEditMenu()

        // Build the menu bar item.
        statusBarController = StatusBarController()

        // Begin tracking the clipboard for history.
        ClipboardHistoryManager.shared.start()

        // Keep the app alive in the background; it has no Dock icon
        // (LSUIElement = true in Info.plist), so it lives only in the menu bar.
        NSApp.activate(ignoringOtherApps: false)
    }

    // MARK: - Edit menu

    private func installEditMenu() {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu

        // NSResponder/NSUndoManager do not declare undo(_:) in the SDK headers,
        // so #selector would fail to compile. Use raw selectors (with colon) which
        // are dynamically routed through the responder chain to NSTextView and
        // the shared NSUndoManager.
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardHistoryManager.shared.stop()
    }

    /// Prevent the app from terminating when the (hidden) main window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
