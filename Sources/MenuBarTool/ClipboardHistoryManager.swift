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

    /// In-memory + persisted history, newest first.
    private(set) var history: [String] = []

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
        lastChangeCount = pasteboard.changeCount
        defaults.set(lastChangeCount, forKey: AppConstants.lastChangeCountKey)
    }

    /// Insert a copied string at the front, de-duplicating and trimming to the max size.
    func add(_ string: String) {
        history.removeAll(where: { $0 == string })
        history.insert(string, at: 0)
        if history.count > AppConstants.maxClipboardHistory {
            history.removeLast(history.count - AppConstants.maxClipboardHistory)
        }
        save()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Remove the entry at the given index.
    func remove(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        save()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Remove the first entry matching the given content.
    func remove(_ content: String) {
        guard let index = history.firstIndex(of: content) else { return }
        history.remove(at: index)
        save()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    /// Clear the entire history.
    func clear() {
        guard !history.isEmpty else { return }
        history.removeAll()
        save()
        NotificationCenter.default.post(name: ClipboardHistoryManager.didChangeNotification, object: nil)
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(history, forKey: AppConstants.clipboardHistoryKey)
    }

    private func load() {
        if let stored = defaults.array(forKey: AppConstants.clipboardHistoryKey) as? [String] {
            history = stored
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
