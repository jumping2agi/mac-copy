import AppKit

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

    private var tableView: NSTableView!
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
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
        super.init(window: window)
        window.contentView = buildContentView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Show

    func showWindow() {
        workingPresets = presetManager.presets.map { $0 } // copy
        tableView.reloadData()
        showWindow(nil)
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

        let actionRow = NSStackView(views: [cancelButton, saveButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.alignment = .centerY

        container.addSubview(scrollView)
        container.addSubview(buttonsRow)
        container.addSubview(actionRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            buttonsRow.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            buttonsRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            buttonsRow.heightAnchor.constraint(equalToConstant: 24),

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
        titleCol.resizingMask = .autoresizingMask
        let contentCol = NSTableColumn(identifier: ColumnIdentifier.content)
        contentCol.resizingMask = .autoresizingMask

        table.addTableColumn(titleCol)
        table.addTableColumn(contentCol)
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

        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(save)

        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Esc
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
    }

    // MARK: - Actions

    @objc private func addRow() {
        workingPresets.append(PresetText(title: "新条目", content: ""))
        let newRow = workingPresets.count - 1
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
        DispatchQueue.main.async { [weak self] in
            self?.startEditing(row: newRow, isTitle: true)
        }
    }

    @objc private func removeRow() {
        let row = tableView.selectedRow
        guard workingPresets.indices.contains(row) else { return }
        workingPresets.remove(at: row)
        tableView.reloadData()
    }

    @objc private func save() {
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

    private func startEditing(row: Int, isTitle: Bool) {
        guard let view = tableView.view(atColumn: isTitle ? 0 : 1,
                                        row: row,
                                        makeIfNecessary: true) as? PresetCellView else { return }
        view.textField?.becomeFirstResponder()
    }
}

private enum ColumnIdentifier {
    static let title = NSUserInterfaceItemIdentifier("title")
    static let content = NSUserInterfaceItemIdentifier("content")
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
            ?? PresetCellView(identifier: cellId)

        let preset = workingPresets[row]
        cell.textField?.stringValue = isTitle ? preset.title : preset.content
        cell.onEdit = { [weak self] newValue in
            guard let self = self, self.workingPresets.indices.contains(row) else { return }
            if isTitle {
                self.workingPresets[row].title = newValue
            } else {
                self.workingPresets[row].content = newValue
            }
        }
        return cell
    }
}

// MARK: - Editable cell

private final class PresetCellView: NSTableCellView {
    var onEdit: ((String) -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
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
        field.lineBreakMode = .byTruncatingTail
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
    }

    @objc private func textChanged(_ sender: NSTextField) {
        onEdit?(sender.stringValue)
    }
}
