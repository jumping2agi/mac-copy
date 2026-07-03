import Foundation

/// Errors that can occur during preset import/export.
enum PresetImportError: Error, LocalizedError {
    case invalidJSON
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "文件不是有效的 JSON 格式"
        case .decodingFailed:
            return "文件内容与快捷文本格式不匹配"
        }
    }
}

/// Loads and persists the user's preset quick-texts in UserDefaults.
final class PresetTextManager {
    static let shared = PresetTextManager()

    /// Notification posted whenever the preset list changes.
    static let didChangeNotification = Notification.Name("PresetTextManagerDidChange")

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// The current list of presets, in display order.
    private(set) var presets: [PresetText] = []

    /// Load presets from UserDefaults, installing sensible defaults on first run.
    private func load() {
        if let data = defaults.data(forKey: AppConstants.presetsKey),
           let decoded = try? JSONDecoder().decode([PresetText].self, from: data) {
            presets = decoded
        } else {
            presets = PresetTextManager.defaultPresets
            save()
        }
    }

    /// Persist the current presets and notify observers.
    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: AppConstants.presetsKey)
        }
        NotificationCenter.default.post(name: PresetTextManager.didChangeNotification, object: nil)
    }

    /// Replace the entire preset list.
    func replace(_ newPresets: [PresetText]) {
        presets = newPresets
        save()
    }

    /// Append a new preset.
    func add(_ preset: PresetText) {
        presets.append(preset)
        save()
    }

    /// Remove the preset at the given index.
    func remove(at index: Int) {
        guard presets.indices.contains(index) else { return }
        presets.remove(at: index)
        save()
    }

    // MARK: - Import / Export

    /// Export all presets as pretty-printed JSON data.
    func exportPresets() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(presets)
    }

    /// Import presets from JSON data, replacing the current list.
    /// - Parameter merge: If true, appends to existing presets; if false, replaces all.
    func importPresets(from data: Data, merge: Bool) throws {
        let decoder = JSONDecoder()
        do {
            let imported = try decoder.decode([PresetText].self, from: data)
            if merge {
                presets.append(contentsOf: imported)
            } else {
                presets = imported
            }
            save()
        } catch {
            throw PresetImportError.decodingFailed(error)
        }
    }

    /// Built-in presets shown on first launch.
    static let defaultPresets: [PresetText] = [
        PresetText(title: "邮箱", content: "support@example.com"),
        PresetText(title: "手机号", content: "138-0000-0000"),
        PresetText(title: "地址", content: "北京市海淀区中关村大街1号"),
        PresetText(title: "签名", content: "祝好，\n张三"),
        PresetText(title: "感谢", content: "非常感谢你的帮助！")
    ]
}
