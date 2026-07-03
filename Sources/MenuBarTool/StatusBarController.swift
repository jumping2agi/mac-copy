import AppKit

/// Owns the `NSStatusItem` and builds/refreshes the dropdown menu.
///
/// Menu layout (top to bottom):
///   - Preset quick-texts (click to copy)
///   - Separator
///   - "剪切板" submenu (clipboard history)
///   - Flexible separator
///   - 设置…
///   - 退出
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let presetManager = PresetTextManager.shared
    private let clipboardManager = ClipboardHistoryManager.shared

    /// Submenu rebuilt lazily when the clipboard history changes.
    private lazy var clipboardSubmenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        return menu
    }()

    private lazy var clipboardMenuItem: NSMenuItem = {
        let item = NSMenuItem()
        item.title = "剪切板"
        item.submenu = clipboardSubmenu
        return item
    }()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        // Rebuild the menu when presets or clipboard history change.
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildMenu),
            name: PresetTextManager.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildClipboardSubmenu),
            name: ClipboardHistoryManager.didChangeNotification, object: nil)

        rebuildMenu()
        rebuildClipboardSubmenu()
    }

    // MARK: - Status item button

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // Prefer the bundled AppIcon if one was generated. In development runs
        // outside an .app bundle, or on hosts without iconutil, fall back to a
        // system symbol or emoji.
        if let icon = loadAppIcon() {
            button.image = icon
            button.image?.isTemplate = true
        } else if let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MenuBarTool") {
            button.image = img
            button.image?.isTemplate = true
        } else {
            button.title = "📋"
        }
        button.toolTip = "MenuBarTool"
    }

    private func loadAppIcon() -> NSImage? {
        // Try the icon inside the running .app bundle first.
        if let bundleIconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: bundleIconURL) {
            // The status bar expects a square, reasonably sized template image.
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Fall back to a Resources/AppIcon.png next to the executable (raw
        // SwiftPM build or development run).
        let pngURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/AppIcon.png")
        if let image = NSImage(contentsOf: pngURL) {
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return nil
    }

    // MARK: - Menu building

    @objc private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        // 1. Preset quick-texts.
        let presets = presetManager.presets
        if presets.isEmpty {
            let empty = NSMenuItem(title: "（暂无快捷文本，请在设置中添加）", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for preset in presets {
                let item = NSMenuItem(
                    title: preset.title,
                    action: #selector(copyPreset(_:)),
                    keyEquivalent: "")
                item.target = self
                item.representedObject = preset.content
                item.toolTip = preset.content
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // 2. Clipboard submenu.
        menu.addItem(clipboardMenuItem)

        // 3. Flexible spacer pushes settings/quit to the bottom.
        let spacer = NSMenuItem()
        spacer.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8))
        menu.addItem(spacer)

        menu.addItem(.separator())

        // 4. Settings + Quit, always at the bottom.
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func rebuildClipboardSubmenu() {
        clipboardSubmenu.removeAllItems()

        let history = clipboardManager.history
        if history.isEmpty {
            let empty = NSMenuItem(title: "（暂无历史记录）", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            clipboardSubmenu.addItem(empty)
            return
        }

        for entry in history {
            let item = NSMenuItem(
                title: ClipboardHistoryManager.preview(of: entry),
                action: #selector(copyHistory(_:)),
                keyEquivalent: "")
            item.target = self
            // Store the actual content so a stale menu (e.g. new copy arrived
            // while open) never copies the wrong item.
            item.representedObject = entry
            item.toolTip = entry
            clipboardSubmenu.addItem(item)
        }

        clipboardSubmenu.addItem(.separator())

        // Per-item delete submenu: lets users remove a specific entry without
        // clearing the entire history. History items above remain click-to-copy.
        let deleteSubmenuItem = NSMenuItem(title: "删除…", action: nil, keyEquivalent: "")
        let deleteSubmenu = NSMenu()
        for entry in history {
            let delItem = NSMenuItem(
                title: ClipboardHistoryManager.preview(of: entry),
                action: #selector(deleteHistoryItem(_:)),
                keyEquivalent: "")
            delItem.target = self
            delItem.representedObject = entry
            delItem.toolTip = entry
            deleteSubmenu.addItem(delItem)
        }
        deleteSubmenuItem.submenu = deleteSubmenu
        clipboardSubmenu.addItem(deleteSubmenuItem)

        clipboardSubmenu.addItem(.separator())

        let clearItem = NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        clipboardSubmenu.addItem(clearItem)
    }

    // MARK: - Actions

    @objc private func copyPreset(_ sender: NSMenuItem) {
        guard let content = sender.representedObject as? String else { return }
        copyToPasteboard(content)
    }

    @objc private func copyHistory(_ sender: NSMenuItem) {
        guard let content = sender.representedObject as? String else { return }
        copyToPasteboard(content)
    }

    @objc private func clearHistory() {
        clipboardManager.clear()
    }

    @objc private func deleteHistoryItem(_ sender: NSMenuItem) {
        guard let content = sender.representedObject as? String else { return }
        clipboardManager.remove(content)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Pasteboard

    /// Write text to the pasteboard *and* register it in our history so the
    /// change is reflected immediately without waiting for the next poll.
    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        // Sync the change count so the next poll doesn't re-add this string.
        clipboardManager.syncChangeCount()
        clipboardManager.add(string)
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    /// Refresh the clipboard submenu right before it opens so it is always current.
    func menuWillOpen(_ menu: NSMenu) {
        if menu === clipboardSubmenu || menu === statusItem.menu {
            rebuildClipboardSubmenu()
        }
    }
}
