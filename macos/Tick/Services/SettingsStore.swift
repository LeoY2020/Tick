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

/// 语言设置（50 种，displayName 用各语言原生名称，所有语言下不译）
enum LanguageSetting: String, CaseIterable, Codable, Identifiable {
    case system
    // 东亚
    case zhHans, zhHant, ja, ko
    // 欧洲
    case en, fr, de, es, it, pt, ptBR, ca, nl, tr, da, sv, nb
    case ru, uk, pl, cs, sk, hu, ro, bg, el, sr, hr, sl, fi
    // 中东
    case ar, he, fa
    // 南亚
    case hi, bn, ta, te, mr, gu, kn, ml, pa, ur, si
    // 东南亚
    case th, vi, id, ms, tl
    // 非洲
    case sw

    var id: String { rawValue }

    /// 显示名称（语言原生名称；"跟随系统"由各语言 strings 翻译，其余原生名不译）
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ptBR: return "Português (Brasil)"
        case .ca: return "Català"
        case .nl: return "Nederlands"
        case .tr: return "Türkçe"
        case .da: return "Dansk"
        case .sv: return "Svenska"
        case .nb: return "Norsk"
        case .ru: return "Русский"
        case .uk: return "Українська"
        case .pl: return "Polski"
        case .cs: return "Čeština"
        case .sk: return "Slovenčina"
        case .hu: return "Magyar"
        case .ro: return "Română"
        case .bg: return "Български"
        case .el: return "Ελληνικά"
        case .sr: return "Српски"
        case .hr: return "Hrvatski"
        case .sl: return "Slovenščina"
        case .fi: return "Suomi"
        case .ar: return "العربية"
        case .he: return "עברית"
        case .fa: return "فارسی"
        case .hi: return "हिन्दी"
        case .bn: return "বাংলা"
        case .ta: return "தமிழ்"
        case .te: return "తెలుగు"
        case .mr: return "मराठी"
        case .gu: return "ગુજરાતી"
        case .kn: return "ಕನ್ನಡ"
        case .ml: return "മലയാളം"
        case .pa: return "ਪੰਜਾਬੀ"
        case .ur: return "اردو"
        case .si: return "සිංහල"
        case .th: return "ไทย"
        case .vi: return "Tiếng Việt"
        case .id: return "Bahasa Indonesia"
        case .ms: return "Bahasa Melayu"
        case .tl: return "Filipino"
        case .sw: return "Kiswahili"
        }
    }

    /// 对应 Locale 标识（跟随系统 = nil，由系统语言决定）
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .ja: return "ja"
        case .ko: return "ko"
        case .en: return "en"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        case .it: return "it"
        case .pt: return "pt"
        case .ptBR: return "pt-BR"
        case .ca: return "ca"
        case .nl: return "nl"
        case .tr: return "tr"
        case .da: return "da"
        case .sv: return "sv"
        case .nb: return "nb"
        case .ru: return "ru"
        case .uk: return "uk"
        case .pl: return "pl"
        case .cs: return "cs"
        case .sk: return "sk"
        case .hu: return "hu"
        case .ro: return "ro"
        case .bg: return "bg"
        case .el: return "el"
        case .sr: return "sr"
        case .hr: return "hr"
        case .sl: return "sl"
        case .fi: return "fi"
        case .ar: return "ar"
        case .he: return "he"
        case .fa: return "fa"
        case .hi: return "hi"
        case .bn: return "bn"
        case .ta: return "ta"
        case .te: return "te"
        case .mr: return "mr"
        case .gu: return "gu"
        case .kn: return "kn"
        case .ml: return "ml"
        case .pa: return "pa"
        case .ur: return "ur"
        case .si: return "si"
        case .th: return "th"
        case .vi: return "vi"
        case .id: return "id"
        case .ms: return "ms"
        case .tl: return "tl"
        case .sw: return "sw"
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
    private static let selectedModelKey = "aiSelectedModel"
    private static let customBaseURLKey = "aiCustomBaseURL"
    private static let customModelKey = "aiCustomModel"

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

    /// 所选 AI 模型（变更即持久化）
    @Published var selectedModel: AIModel {
        didSet { persist() }
    }

    /// 自定义模型地址（含协议与主机，如 https://api.example.com/v1）
    @Published var customBaseURL: String {
        didSet { persist() }
    }

    /// 自定义模型名
    @Published var customModel: String {
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
        var model = AIModel.appleIntelligence
        var customBaseURL = ""
        var customModel = ""

        if let snapshot = DataBackupManager.shared.loadSettingsSnapshot() {
            // Keychain 快照优先：卸载重装后 UserDefaults 已清空，仍可恢复设置
            scheme = ColorSchemeSetting(rawValue: snapshot.colorSchemeRaw) ?? scheme
            lang = LanguageSetting(rawValue: snapshot.languageRaw) ?? lang
            syncEnabled = snapshot.iCloudSyncEnabled
            if let raw = snapshot.selectedModelRaw {
                model = AIModel(rawValue: raw) ?? model
            }
            customBaseURL = snapshot.customBaseURL ?? ""
            customModel = snapshot.customModel ?? ""
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
            if let raw = defaults.string(forKey: Self.selectedModelKey) {
                model = AIModel(rawValue: raw) ?? model
            }
            customBaseURL = defaults.string(forKey: Self.customBaseURLKey) ?? ""
            customModel = defaults.string(forKey: Self.customModelKey) ?? ""
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
            if let raw = kvs.string(forKey: Self.selectedModelKey) {
                model = AIModel(rawValue: raw) ?? model
            }
            if let raw = kvs.string(forKey: Self.customBaseURLKey) { customBaseURL = raw }
            if let raw = kvs.string(forKey: Self.customModelKey) { customModel = raw }
        }

        colorScheme = scheme
        language = lang
        iCloudSyncEnabled = syncEnabled
        selectedModel = model
        self.customBaseURL = customBaseURL
        self.customModel = customModel
    }

    /// 持久化当前设置：UserDefaults + Keychain 备份（+ 开启同步时写入 iCloud KVS）
    func persist() {
        // 本地
        let defaults = UserDefaults.standard
        defaults.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
        defaults.set(language.rawValue, forKey: Self.languageKey)
        defaults.set(iCloudSyncEnabled, forKey: Self.iCloudSyncKey)
        defaults.set(selectedModel.rawValue, forKey: Self.selectedModelKey)
        defaults.set(customBaseURL, forKey: Self.customBaseURLKey)
        defaults.set(customModel, forKey: Self.customModelKey)

        // Keychain 防删除备份（卸载重装可恢复；iCloudSyncEnabled 兼作"曾开启同步"标记）
        DataBackupManager.shared.backupSettings(
            SettingsSnapshot(colorSchemeRaw: colorScheme.rawValue,
                             languageRaw: language.rawValue,
                             iCloudSyncEnabled: iCloudSyncEnabled,
                             selectedModelRaw: selectedModel.rawValue,
                             customBaseURL: customBaseURL,
                             customModel: customModel))

        // 开启同步时写入 iCloud KVS，设备间同步设置
        if iCloudSyncEnabled {
            let kvs = NSUbiquitousKeyValueStore.default
            kvs.set(colorScheme.rawValue, forKey: Self.colorSchemeKey)
            kvs.set(language.rawValue, forKey: Self.languageKey)
            kvs.set(iCloudSyncEnabled, forKey: Self.iCloudSyncKey)
            kvs.set(selectedModel.rawValue, forKey: Self.selectedModelKey)
            kvs.set(customBaseURL, forKey: Self.customBaseURLKey)
            kvs.set(customModel, forKey: Self.customModelKey)
            kvs.synchronize()
        }
    }
}
