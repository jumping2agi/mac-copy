import AppKit
import UniformTypeIdentifiers

/// A settings window for editing the preset quick-texts.
///
/// Uses an editable `NSTableView` with two columns (标题 / 内容), plus
/// Add/Remove and Save/Cancel buttons. Editing is done on a working copy;
/// changes are committed to `PresetTextManager` only on Save.
final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private let presetManager = PresetTextManager.shared

    /// Working copy edited in the table; committed on Save.
    private var workingPresets: [PresetText] = []

    /// The text field currently in edit mode, if any.
    ///
    /// We keep this around so we can flush its value back into the working copy
    /// before Save / Export / Close. NSTextField only sends its action when the
    /// user presses Enter or the field resigns first responder, so a user who
    /// types directly into a cell and then clicks "Save" would otherwise lose
    /// the last edit.
    private weak var activeEditor: NSTextField?

    private var tableView: NSTableView!
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let importButton = NSButton(title: "导入", target: nil, action: nil)
    private let exportButton = NSButton(title: "导出", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)
    private let cancelButton = NSButton(title: "取消", target: nil, action: nil)

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "设置 — 快捷文本"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 300)
        window.delegate = self
        super.init(window: window)
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Show

    /// Present the settings window, loading a fresh working copy from the manager.
    /// If the window is already visible (e.g. user clicked 设置… again from the
    /// status bar), just bring it to the front — don't reload, which would
    /// silently discard unsaved edits.
    func showSettings() {
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        workingPresets = presetManager.presets.map { $0 } // copy
        tableView.reloadData()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 380))
        container.translatesAutoresizingMaskIntoConstraints = false

        // Scrollable table.
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = makeTableView()
        scrollView.documentView = tableView

        configureButtons()

        let buttonsRow = NSStackView(views: [addButton, removeButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 6
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        buttonsRow.alignment = .centerY

        let ioRow = NSStackView(views: [importButton, exportButton])
        ioRow.orientation = .horizontal
        ioRow.spacing = 8
        ioRow.translatesAutoresizingMaskIntoConstraints = false
        ioRow.alignment = .centerY

        let actionRow = NSStackView(views: [cancelButton, saveButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.alignment = .centerY

        container.addSubview(scrollView)
        container.addSubview(buttonsRow)
        container.addSubview(ioRow)
        container.addSubview(actionRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            buttonsRow.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            buttonsRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            buttonsRow.heightAnchor.constraint(equalToConstant: 24),

            ioRow.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            ioRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            ioRow.heightAnchor.constraint(equalToConstant: 24),

            actionRow.topAnchor.constraint(equalTo: buttonsRow.bottomAnchor, constant: 12),
            actionRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            actionRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            actionRow.heightAnchor.constraint(equalToConstant: 28),
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

        let titleCol = NSTableColumn(identifier: ColumnIdentifier.title)
        titleCol.width = 140
        titleCol.minWidth = 80
        titleCol.resizingMask = .autoresizingMask
        let contentCol = NSTableColumn(identifier: ColumnIdentifier.content)
        contentCol.width = 340
        contentCol.minWidth = 200
        contentCol.resizingMask = .autoresizingMask

        table.addTableColumn(titleCol)
        table.addTableColumn(contentCol)
        table.dataSource = self
        table.delegate = self
        table.doubleAction = #selector(startEditingSelectedRow)
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
        cancelButton.keyEquivalent = "\u{1b}" // Esc
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
    }

    // MARK: - Editing lifecycle

    /// Flush the currently active cell editor back into `workingPresets`.
    ///
    /// Must be called before any operation that reads the working copy for
    /// persistence (Save, Export) or structural changes (Remove, Import).
    private func commitActiveEditor() {
        guard let editor = activeEditor else { return }
        // Resigning first responder sends textDidEndEditing(_:) to the cell,
        // which writes the value back to the model.
        window?.makeFirstResponder(nil)
        activeEditor = nil
        // Keep the editor's string in sync in case the cell was reused.
        _ = editor.stringValue
    }

    @objc private func startEditingSelectedRow() {
        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        startEditing(row: row, isTitle: true)
    }

    private func startEditing(row: Int, isTitle: Bool) {
        // Ensure the row is visible and selected.
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)

        // Make sure the cell exists. On the first layout pass the view may not
        // be ready immediately, so retry once on the next runloop tick.
        guard let view = tableView.view(atColumn: isTitle ? 0 : 1,
                                        row: row,
                                        makeIfNecessary: true) as? PresetCellView else {
            DispatchQueue.main.async { [weak self] in
                self?.startEditing(row: row, isTitle: isTitle)
            }
            return
        }
        view.textField?.becomeFirstResponder()
    }

    // MARK: - Actions

    @objc private func addRow() {
        commitActiveEditor()

        workingPresets.append(PresetText(title: "新条目", content: ""))
        let newRow = workingPresets.count - 1
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)

        // Defer editing so the table has finished laying out the new row.
        DispatchQueue.main.async { [weak self] in
            self?.startEditing(row: newRow, isTitle: true)
        }
    }

    @objc private func removeRow() {
        commitActiveEditor()

        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        workingPresets.remove(at: row)
        tableView.reloadData()

        // Maintain a sensible selection.
        let newSelection = min(row, workingPresets.count - 1)
        if newSelection >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: newSelection), byExtendingSelection: false)
        }
    }

    @objc private func save() {
        commitActiveEditor()

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
        commitActiveEditor()
        window?.orderOut(nil)
    }

    // MARK: - Import / Export

    @objc private func exportPresets() {
        commitActiveEditor()

        let panel = NSSavePanel()
        panel.title = "导出快捷文本"
        panel.nameFieldStringValue = "MenuBarTool-presets.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            // Export the working copy (what the user sees in the table), not the
            // saved presets — otherwise unsaved edits would be silently missing
            // from the exported file, which is inconsistent with import.
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
        commitActiveEditor()

        let panel = NSOpenPanel()
        panel.title = "导入快捷文本"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let imported = try decoder.decode([PresetText].self, from: data)

                // Merge imported items, skipping exact duplicates so the user
                // doesn't end up with redundant entries.
                let existing = Set(workingPresets.map(identityKey))
                let unique = imported.filter { existing.contains(identityKey($0)) == false }
                workingPresets.append(contentsOf: unique)
                tableView.reloadData()
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
    static let content = NSUserInterfaceItemIdentifier("content")
}

private func identityKey(_ preset: PresetText) -> String {
    "\(preset.title)\t\(preset.content)"
}

// MARK: - NSWindowController / NSWindowDelegate

extension SettingsWindowController: NSWindowDelegate {
    /// If the user closes the settings window without saving, end any active
    /// edit cleanly (without writing it back — it's a cancel).
    func windowWillClose(_ notification: Notification) {
        activeEditor = nil
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
        guard workingPresets.indices.contains(row),
              let column = tableColumn else { return nil }

        let isTitle = (column.identifier == ColumnIdentifier.title)
        let cellId = column.identifier
        let cell = (tableView.makeView(withIdentifier: cellId, owner: self) as? PresetCellView)
            ?? PresetCellView(identifier: cellId, isTitle: isTitle)

        let preset = workingPresets[row]
        cell.textField?.stringValue = isTitle ? preset.title : preset.content
        cell.onEditBegan = { [weak self] field in
            self?.activeEditor = field
        }
        cell.onEditEnded = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.activeEditor = nil
            let currentRow = self.tableView.row(for: cell)
            guard self.workingPresets.indices.contains(currentRow) else { return }
            if cell.isTitleColumn {
                self.workingPresets[currentRow].title = cell.textField?.stringValue ?? ""
            } else {
                self.workingPresets[currentRow].content = cell.textField?.stringValue ?? ""
            }
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Starting an edit via double-click is handled by doubleAction, but if
        // the user single-clicks a row and starts typing, AppKit does not
        // automatically enter edit mode. We keep the simple double-click model.
    }
}

// MARK: - Editable cell

private final class PresetCellView: NSTableCellView {
    var onEditBegan: ((NSTextField) -> Void)?
    var onEditEnded: (() -> Void)?
    let isTitleColumn: Bool

    init(identifier: NSUserInterfaceItemIdentifier, isTitle: Bool) {
        self.isTitleColumn = isTitle
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        // byWordWrapping works correctly in edit mode (byTruncatingTail is a
        // display-only mode that breaks selection/caret behavior while editing).
        field.lineBreakMode = .byWordWrapping
        field.target = self
        field.action = #selector(textChanged)
        addSubview(field)
        self.textField = field

        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        // Track edit lifecycle so the controller can flush values before Save.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidBeginEditing(_:)),
            name: NSTextField.textDidBeginEditingNotification,
            object: field)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidEndEditing(_:)),
            name: NSTextField.textDidEndEditingNotification,
            object: field)
    }

    @objc private func textDidBeginEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        onEditBegan?(field)
    }

    @objc private func textDidEndEditing(_ notification: Notification) {
        onEditEnded?()
    }

    @objc private func textChanged(_ sender: NSTextField) {
        onEditEnded?()
    }
}
