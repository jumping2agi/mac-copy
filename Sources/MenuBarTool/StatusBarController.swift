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

        presetManager.load()

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
        if let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MenuBarTool") {
            button.image = img
            button.image?.isTemplate = true
        } else {
            // Fallback for older systems.
            button.title = "📋"
        }
        button.toolTip = "MenuBarTool"
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

        for (index, entry) in history.enumerated() {
            let item = NSMenuItem(
                title: ClipboardHistoryManager.preview(of: entry),
                action: #selector(copyHistory(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = index
            item.toolTip = entry
            clipboardSubmenu.addItem(item)
        }

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
        guard let index = sender.representedObject as? Int,
              clipboardManager.history.indices.contains(index) else { return }
        let content = clipboardManager.history[index]
        copyToPasteboard(content)
    }

    @objc private func clearHistory() {
        clipboardManager.clear()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
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
