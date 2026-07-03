import Foundation

/// Centralized constants for the app.
enum AppConstants {
    /// UserDefaults key for the persisted preset quick-texts.
    static let presetsKey = "com.menubar.tool.presets"

    /// UserDefaults key for the persisted clipboard history.
    static let clipboardHistoryKey = "com.menubar.tool.clipboardHistory"

    /// UserDefaults key for the last-seen pasteboard change count.
    static let lastChangeCountKey = "com.menubar.tool.lastChangeCount"

    /// Maximum number of clipboard history items to keep.
    static let maxClipboardHistory = 50

    /// Maximum characters of a clipboard entry to show in the submenu preview.
    static let previewLength = 60

    /// Polling interval (seconds) for the pasteboard.
    static let clipboardPollInterval: TimeInterval = 0.5
}

/// A single preset quick-text entry shown in the dropdown menu.
struct PresetText: Codable, Equatable {
    var title: String
    var content: String
}
