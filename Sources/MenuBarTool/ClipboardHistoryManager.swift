import AppKit

/// Tracks the system pasteboard and keeps a short history of copied text.
///
/// Because `NSPasteboard` is poll-based (no change notifications on macOS),
/// we poll `pasteboard.changeCount` on a timer and record new string items.
final class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()

    /// Notification posted whenever the history changes.
    static let didChangeNotification = Notification.Name("ClipboardHistoryDidChange")

    private let defaults: UserDefaults
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let lock = NSLock()

    /// In-memory + persisted history, newest first.
    private var _history: [String] = []

    /// Thread-safe snapshot of the current history.
    var history: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _history
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.lastChangeCount = defaults.integer(forKey: AppConstants.lastChangeCountKey)
        load()
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: AppConstants.clipboardPollInterval,
                      repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // Do an immediate poll so the menu is fresh on first open.
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        defaults.set(lastChangeCount, forKey: AppConstants.lastChangeCountKey)

        // Only track plain string contents.
        guard let item = pasteboard.string(forType: .string),
              !item.isEmpty else {
            return
        }
        add(item)
    }

    // MARK: - Mutations

    /// Sync `lastChangeCount` with the pasteboard after a manual write so the
    /// next poll doesn't re-detect the change we just made ourselves.
    func syncChangeCount() {
        lock.lock()
        defer { lock.unlock() }
        lastChangeCount = pasteboard.changeCount
        defaults.set(lastChangeCount, forKey: AppConstants.lastChangeCountKey)
    }

    /// Insert a copied string at the front, de-duplicating and trimming to the max size.
    func add(_ string: String) {
        lock.lock()
        _history.removeAll(where: { $0 == string })
        _history.insert(string, at: 0)
        if _history.count > AppConstants.maxClipboardHistory {
            _history.removeLast(_history.count - AppConstants.maxClipboardHistory)
        }
        defaults.set(_history, forKey: AppConstants.clipboardHistoryKey)
        lock.unlock()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Remove the entry at the given index.
    func remove(at index: Int) {
        lock.lock()
        guard _history.indices.contains(index) else { lock.unlock(); return }
        _history.remove(at: index)
        defaults.set(_history, forKey: AppConstants.clipboardHistoryKey)
        lock.unlock()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Remove the first entry matching the given content.
    func remove(_ content: String) {
        lock.lock()
        guard let index = _history.firstIndex(of: content) else { lock.unlock(); return }
        _history.remove(at: index)
        defaults.set(_history, forKey: AppConstants.clipboardHistoryKey)
        lock.unlock()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Clear the entire history.
    func clear() {
        lock.lock()
        guard !_history.isEmpty else { lock.unlock(); return }
        _history.removeAll()
        defaults.set(_history, forKey: AppConstants.clipboardHistoryKey)
        lock.unlock()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    // MARK: - Persistence

    private func load() {
        if let stored = defaults.array(forKey: AppConstants.clipboardHistoryKey) as? [String] {
            _history = stored
        }
    }

    // MARK: - Helpers

    /// A single-line, length-limited preview suitable for a menu item title.
    static func preview(of string: String) -> String {
        let flattened = string
            .replacingOccurrences(of: "\n", with: " ⏎ ")
            .replacingOccurrences(of: "\t", with: " ")
        let trimmed = flattened.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= AppConstants.previewLength {
            return trimmed
        }
        return String(trimmed.prefix(AppConstants.previewLength)) + "…"
    }
}
