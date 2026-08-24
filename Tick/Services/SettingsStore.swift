import SwiftUI

// MARK: - 配色方案设置

/// 配色方案设置
enum ColorSchemeSetting: String, CaseIterable, Codable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    /// 显示名称（视图中作为 LocalizedStringKey 本地化）
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "亮色"
        case .dark: return "暗色"
        }
    }
}

// MARK: - 语言设置

/// 语言设置
enum LanguageSetting: String, CaseIterable, Codable, Identifiable {
    case system, zhHans, zhHant, en, ja, ko

    var id: String { rawValue }

    /// 显示名称（语言原生名称，视图中作为 LocalizedStringKey 本地化；
    /// 原生名称在所有语言下保持不译，"跟随系统"由各语言 strings 翻译）
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    /// 对应 Locale 标识（跟随系统 = nil，由系统语言决定）
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        }
    }
}

// MARK: - 设置存储

/// 设置存储：UserDefaults 本地 + Keychain 防删除备份 + iCloud KVS（开启同步时）。
/// 读取优先级：Keychain 快照（卸载重装可恢复）→ UserDefaults → 默认值；
/// 曾开启 iCloud 同步且 KVS 有值时，以 KVS 为准（设备间最新设置）。
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// UserDefaults / iCloud KVS 存储键
    private static let colorSchemeKey = "colorScheme"
    private static let languageKey = "language"
    private static let iCloudSyncKey = "iCloudSyncEnabled"

    /// 配色方案（变更即持久化）
    @Published var colorScheme: ColorSchemeSetting {
        didSet { persist() }
    }

    /// 语言（变更即持久化）
    @Published var language: LanguageSetting {
        didSet { persist() }
    }

    /// iCloud 同步开关（变更即持久化）
    @Published var iCloudSyncEnabled: Bool {
        didSet { persist() }
    }

    /// 供根视图 `.preferredColorScheme()` 使用：跟随系统 → nil
    var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 供根视图 `.environment(\.locale, ...)` 使用：跟随系统 → nil
    var currentLocale: Locale? {
        guard let identifier = language.localeIdentifier else { return nil }
        return Locale(identifier: identifier)
    }

    init() {
        var scheme = ColorSchemeSetting.system
        var lang = LanguageSetting.system
        var syncEnabled = false

        if let snapshot = DataBackupManager.shared.loadSettingsSnapshot() {
            // Keychain 快照优先：卸载重装后 UserDefaults 已清空，仍可恢复设置
            scheme = ColorSchemeSetting(rawValue: snapshot.colorSchemeRaw) ?? scheme
            lang = LanguageSetting(rawValue: snapshot.languageRaw) ?? lang
            syncEnabled = snapshot.iCloudSyncEnabled
        } else {
            // 无 Keychain 快照 → 回退 UserDefaults
            let defaults = UserDefaults.standard
            if let raw = defaults.string(forKey: Self.colorSchemeKey) {
                scheme = ColorSchemeSetting(rawValue: raw) ?? scheme
            }
            if let raw = defaults.string(forKey: Self.languageKey) {
                lang = LanguageSetting(rawValue: raw) ?? lang
            }
            syncEnabled = defaults.bool(forKey: Self.iCloudSyncKey)
        }

        // 曾开启 iCloud 同步且 KVS 有值 → 以 KVS 为准（设备间同步的最新设置）
        if syncEnabled {
            let kvs = NSUbiquitousKeyValueStore.default
            kvs.synchronize()
            if let raw = kvs.string(forKey: Self.colorSchemeKey) {
                scheme = ColorSchemeSetting(rawValue: raw) ?? scheme
            }
            if let raw = kvs.string(forKey: Self.languageKey) {
                lang = LanguageSetting(rawValue: raw) ?? lang
            }
            if let enabled = kvs.object(forKey: Self.iCloudSyncKey) as? Bool {
                syncEnabled = enabled
            }
        }

        colorScheme = scheme
        language = lang
        iCloudSyncEnabled = syncEnabled
    }

    /// 持久化当前设置：UserDefaults + Keychain 备份（+ 开启同步时写入 iCloud KVS）
    func persist() {
        // 本地
        let defaults = UserDefaults.standard
        defaults.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
        defaults.set(language.rawValue, forKey: Self.languageKey)
        defaults.set(iCloudSyncEnabled, forKey: Self.iCloudSyncKey)

        // Keychain 防删除备份（卸载重装可恢复；iCloudSyncEnabled 兼作"曾开启同步"标记）
        DataBackupManager.shared.backupSettings(
            SettingsSnapshot(colorSchemeRaw: colorScheme.rawValue,
                             languageRaw: language.rawValue,
                             iCloudSyncEnabled: iCloudSyncEnabled))

        // 开启同步时写入 iCloud KVS，设备间同步设置
        if iCloudSyncEnabled {
            let kvs = NSUbiquitousKeyValueStore.default
            kvs.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
            kvs.set(language.rawValue, forKey: Self.languageKey)
            kvs.set(iCloudSyncEnabled, forKey: Self.iCloudSyncKey)
            kvs.synchronize()
        }
    }
}
