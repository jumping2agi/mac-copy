import AppKit
import UniformTypeIdentifiers

/// A settings window for editing the preset quick-texts.
///
/// Master–detail layout:
///   - Left:  a list of preset titles (single-click to select for editing).
///   - Right: a title field and a multi-line content text view for the
///            currently selected preset.
///   - Bottom: + / − (add/remove), 导入 / 导出, 取消 / 保存.
///
/// Editing is done on a working copy; changes are committed to
/// `PresetTextManager` only on Save. The edit panel writes back to the working
/// copy on every keystroke, so Save never loses the last edit.
final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private let presetManager = PresetTextManager.shared

    /// Working copy edited in the table; committed on Save.
    private var workingPresets: [PresetText] = []

    private var tableView: NSTableView!
    private var titleField: NSTextField!
    private var contentTextView: NSTextView!

    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let importButton = NSButton(title: "导入", target: nil, action: nil)
    private let exportButton = NSButton(title: "导出", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)

    /// Guard against feedback loops when we programmatically update the edit
    /// panel from the model (e.g. after a selection change).
    private var isSyncingPanel = false

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "设置 — 快捷文本"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 360)
        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Show

    /// Present the settings window. If already visible, just bring it to the
    /// front without reloading (so unsaved edits are preserved).
    func showSettings() {
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        workingPresets = presetManager.presets.map { $0 } // copy
        tableView.reloadData()
        if !workingPresets.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            updateEditPanel()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 440))
        container.translatesAutoresizingMaskIntoConstraints = false

        // --- Left: list ---
        let listScroll = NSScrollView()
        listScroll.translatesAutoresizingMaskIntoConstraints = false
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder
        tableView = makeTableView()
        listScroll.documentView = tableView

        configureButtons()

        // --- Right: editor ---
        let titleLabel = NSTextField(labelWithString: "标题")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        titleField = NSTextField()
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.placeholderString = "显示在菜单中的名称"
        titleField.target = self
        titleField.action = #selector(titleFieldAction)
        // Live-commit title edits so Save never loses the last keystroke.
        NotificationCenter.default.addObserver(
            self, selector: #selector(titleFieldTextChanged),
            name: NSControl.textDidChangeNotification, object: titleField)

        let contentLabel = NSTextField(labelWithString: "内容")
        contentLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        contentTextView = NSTextView()
        contentTextView.isRichText = false
        contentTextView.font = NSFont.systemFont(ofSize: 13)
        contentTextView.textColor = .labelColor
        contentTextView.backgroundColor = .textBackgroundColor
        contentTextView.isVerticallyResizable = true
        contentTextView.isHorizontallyResizable = false
        contentTextView.textContainer?.widthTracksTextView = true
        contentTextView.textContainer?.size = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        contentTextView.autoresizingMask = [.width]
        contentTextView.delegate = self

        let contentScroll = NSScrollView()
        contentScroll.translatesAutoresizingMaskIntoConstraints = false
        contentScroll.hasVerticalScroller = true
        contentScroll.borderType = .bezelBorder
        contentScroll.documentView = contentTextView

        let editor = NSView()
        editor.translatesAutoresizingMaskIntoConstraints = false
        editor.addSubview(titleLabel)
        editor.addSubview(titleField)
        editor.addSubview(contentLabel)
        editor.addSubview(contentScroll)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: editor.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: editor.leadingAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 36),

            titleField.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            titleField.trailingAnchor.constraint(equalTo: editor.trailingAnchor),

            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            contentLabel.leadingAnchor.constraint(equalTo: editor.leadingAnchor),
            contentLabel.widthAnchor.constraint(equalToConstant: 36),

            contentScroll.topAnchor.constraint(equalTo: contentLabel.topAnchor),
            contentScroll.leadingAnchor.constraint(equalTo: contentLabel.trailingAnchor, constant: 8),
            contentScroll.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
            contentScroll.bottomAnchor.constraint(equalTo: editor.bottomAnchor),
        ])

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        // --- Bottom rows ---
        let listActions = NSStackView(views: [addButton, removeButton])
        listActions.orientation = .horizontal
        listActions.spacing = 6
        listActions.translatesAutoresizingMaskIntoConstraints = false
        listActions.alignment = .centerY

        let fileActions = NSStackView(views: [importButton, exportButton])
        fileActions.orientation = .horizontal
        fileActions.spacing = 8
        fileActions.translatesAutoresizingMaskIntoConstraints = false
        fileActions.alignment = .centerY

        let saveActions = NSStackView(views: [cancelButton, saveButton])
        saveActions.orientation = .horizontal
        saveActions.spacing = 8
        saveActions.translatesAutoresizingMaskIntoConstraints = false
        saveActions.alignment = .centerY

        container.addSubview(listScroll)
        container.addSubview(separator)
        container.addSubview(editor)
        container.addSubview(listActions)
        container.addSubview(fileActions)
        container.addSubview(saveActions)

        NSLayoutConstraint.activate([
            listScroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            listScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            listScroll.widthAnchor.constraint(equalToConstant: 180),
            listScroll.bottomAnchor.constraint(equalTo: listActions.topAnchor, constant: -12),

            separator.topAnchor.constraint(equalTo: listScroll.topAnchor),
            separator.bottomAnchor.constraint(equalTo: listScroll.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor, constant: 12),

            editor.topAnchor.constraint(equalTo: listScroll.topAnchor),
            editor.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 12),
            editor.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            editor.bottomAnchor.constraint(equalTo: saveActions.topAnchor, constant: -12),

            listActions.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            listActions.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            listActions.heightAnchor.constraint(equalToConstant: 28),

            fileActions.leadingAnchor.constraint(equalTo: listActions.trailingAnchor, constant: 16),
            fileActions.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            fileActions.heightAnchor.constraint(equalToConstant: 28),

            saveActions.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            saveActions.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            saveActions.heightAnchor.constraint(equalToConstant: 28),
        ])

        return container
    }

    private func makeTableView() -> NSTableView {
        let table = NSTableView()
        table.headerView = nil
        table.backgroundColor = .clear
        table.rowSizeStyle = .default
        table.gridStyleMask = .solidHorizontalGridLineMask
        table.allowsMultipleSelection = false
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let col = NSTableColumn(identifier: ColumnIdentifier.title)
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        return table
    }

    private func configureButtons() {
        addButton.bezelStyle = .smallSquare
        addButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        addButton.target = self
        addButton.action = #selector(addRow)

        removeButton.bezelStyle = .smallSquare
        removeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        removeButton.target = self
        removeButton.action = #selector(removeRow)

        importButton.bezelStyle = .rounded
        importButton.target = self
        importButton.action = #selector(importPresets)

        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportPresets)

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(save)

        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
    }

    // MARK: - Panel sync

    /// Update the right-hand edit panel to reflect the currently selected row.
    private func updateEditPanel() {
        isSyncingPanel = true
        defer { isSyncingPanel = false }

        let row = tableView.selectedRow
        let hasSelection = workingPresets.indices.contains(row)
        // Keep action buttons in sync with the selection / list state.
        removeButton.isEnabled = hasSelection
        exportButton.isEnabled = !workingPresets.isEmpty

        if hasSelection {
            let preset = workingPresets[row]
            titleField.stringValue = preset.title
            contentTextView.string = preset.content
            setEditingEnabled(true)
        } else {
            titleField.stringValue = ""
            contentTextView.string = ""
            setEditingEnabled(false)
        }
    }

    private func setEditingEnabled(_ enabled: Bool) {
        titleField.isEnabled = enabled
        contentTextView.isEditable = enabled
        contentTextView.isSelectable = enabled
    }

    /// Write the current edit panel values back into the working copy for the
    /// selected row. Called on every keystroke.
    private func commitEditPanelToModel() {
        guard !isSyncingPanel else { return }
        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        workingPresets[row].title = titleField.stringValue
        workingPresets[row].content = contentTextView.string
    }

    // MARK: - Actions

    @objc private func addRow() {
        commitEditPanelToModel()
        workingPresets.append(PresetText(title: "新条目", content: ""))
        let newRow = workingPresets.count - 1
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
        // Always refresh the panel explicitly: selectRowIndexes may not trigger
        // tableViewSelectionDidChange if the index happens to match the previous
        // selection (e.g. adding when row 0 was already selected).
        updateEditPanel()
        // Focus the title field and select all so the user can immediately
        // type to replace the default "新条目" name.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window?.makeFirstResponder(self.titleField)
            self.titleField.currentEditor()?.selectAll(nil)
        }
    }

    @objc private func removeRow() {
        commitEditPanelToModel()
        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        workingPresets.remove(at: row)
        tableView.reloadData()
        let newSelection = min(row, workingPresets.count - 1)
        if newSelection >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: newSelection), byExtendingSelection: false)
        }
        // Always refresh the panel: after reloadData the selection index may
        // not have changed (e.g. removing row 0 from a multi-item list), so
        // tableViewSelectionDidChange might not fire and the panel would show
        // stale data from the deleted row.
        updateEditPanel()
    }

    @objc private func titleFieldAction() {
        // Enter pressed in the title field — commit and move focus to content.
        commitEditPanelToModel()
        refreshSelectedTableRow()
        window?.makeFirstResponder(contentTextView)
    }

    @objc private func titleFieldTextChanged() {
        commitEditPanelToModel()
        refreshSelectedTableRow()
    }

    private func refreshSelectedTableRow() {
        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func save() {
        commitEditPanelToModel()
        // Model is already in sync via live commits; just clean and persist.
        let cleaned = workingPresets.map { preset -> PresetText in
            let title = preset.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return PresetText(
                title: title.isEmpty ? "（未命名）" : title,
                content: preset.content)
        }
        presetManager.replace(cleaned)
        window?.orderOut(nil)
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    // MARK: - Import / Export

    @objc private func exportPresets() {
        commitEditPanelToModel()
        let panel = NSSavePanel()
        panel.title = "导出快捷文本"
        panel.nameFieldStringValue = "MenuBarTool-presets.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                let data = try encoder.encode(workingPresets)
                try data.write(to: url, options: .atomic)
            } catch {
                showAlert(title: "导出失败", message: error.localizedDescription)
            }
        }
    }

    @objc private func importPresets() {
        commitEditPanelToModel()
        let panel = NSOpenPanel()
        panel.title = "导入快捷文本"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let imported = try decoder.decode([PresetText].self, from: data)
                let existing = Set(workingPresets.map(identityKey))
                let unique = imported.filter { existing.contains(identityKey($0)) == false }
                workingPresets.append(contentsOf: unique)
                tableView.reloadData()
                if tableView.selectedRow < 0, !workingPresets.isEmpty {
                    tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
                // Refresh panel + button states after structural change.
                updateEditPanel()
            } catch {
                showAlert(title: "导入失败", message: error.localizedDescription)
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

// MARK: - Helpers

private enum ColumnIdentifier {
    static let title = NSUserInterfaceItemIdentifier("title")
}

private func identityKey(_ preset: PresetText) -> String {
    "\(preset.title)\t\(preset.content)"
}

// MARK: - NSWindowDelegate

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

// MARK: - NSTableViewDataSource

extension SettingsWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        workingPresets.count
    }
}

// MARK: - NSTableViewDelegate

extension SettingsWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard workingPresets.indices.contains(row) else { return nil }
        let cell = (tableView.makeView(withIdentifier: ColumnIdentifier.title, owner: self) as? NSTableCellView)
            ?? makeTitleCell()
        let title = workingPresets[row].title
        cell.textField?.stringValue = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（未命名）" : title
        return cell
    }

    private func makeTitleCell() -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = ColumnIdentifier.title
        let field = NSTextField(labelWithString: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.lineBreakMode = .byTruncatingTail
        field.font = NSFont.systemFont(ofSize: 13)
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateEditPanel()
    }
}

// MARK: - NSTextViewDelegate

extension SettingsWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        commitEditPanelToModel()
    }
}
