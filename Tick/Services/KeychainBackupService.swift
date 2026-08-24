import Foundation
import Security

// MARK: - 备份错误

/// Keychain 备份错误
enum BackupError: LocalizedError, Equatable {
    /// 写入失败（关联 OSStatus）
    case writeFailed(Int)
    /// 读取失败（关联 OSStatus）
    case readFailed(Int)
    /// 条目不存在
    case itemNotFound
    /// 数据损坏（读取结果类型异常）
    case dataCorrupted
    /// 容量超限（约 512KB~数 MB，视设备而定）
    case insufficientSpace

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "Keychain 写入失败（OSStatus \(status)）"
        case .readFailed(let status):
            return "Keychain 读取失败（OSStatus \(status)）"
        case .itemNotFound:
            return "Keychain 备份条目不存在"
        case .dataCorrupted:
            return "Keychain 备份数据损坏"
        case .insufficientSpace:
            return "备份数据超出 Keychain 容量限制，建议开启 iCloud 同步"
        }
    }
}

// MARK: - Keychain 备份服务

/// Keychain 备份服务：kSecClassGenericPassword，kSecAttrAccessible = WhenUnlockedThisDeviceOnly。
/// 应用卸载后条目保留（防删除保护），重装可读取恢复。
final class KeychainBackupService {
    static let shared = KeychainBackupService()

    /// 服务名（shared 实例 = Bundle ID；测试可注入唯一值隔离条目）
    private let service: String
    /// 应用数据条目账号名（Bundle ID + "appData"）
    private let appDataKey: String
    /// 用户设置条目账号名（Bundle ID + "settings"）
    private let settingsKey: String
    /// 单条目大小硬阈值（1MB；Keychain 实际限制约 512KB~数 MB，视设备而定）
    private let maxItemSizeBytes = 1_048_576

    /// - Parameter service: 服务名，默认 `Bundle.main.bundleIdentifier ?? "com.tick.app"`
    init(service: String = Bundle.main.bundleIdentifier ?? "com.tick.app") {
        self.service = service
        appDataKey = service + "appData"
        settingsKey = service + "settings"
    }

    // MARK: - 应用数据（目标 + 任务）

    /// 写入应用数据（存在则更新，不存在则新增；超过 1MB 阈值抛 insufficientSpace）
    func saveAppData(_ data: Data) throws {
        try save(data, account: appDataKey)
    }

    /// 读取应用数据（无备份或读取失败返回 nil）
    func loadAppData() -> Data? {
        try? load(account: appDataKey)
    }

    // MARK: - 用户设置

    /// 写入用户设置（存在则更新，不存在则新增）
    func saveSettings(_ data: Data) throws {
        try save(data, account: settingsKey)
    }

    /// 读取用户设置（无备份或读取失败返回 nil）
    func loadSettings() -> Data? {
        try? load(account: settingsKey)
    }
}

// MARK: - 通用读写

private extension KeychainBackupService {

    /// 通用写入：先 SecItemUpdate 更新已有条目；errSecItemNotFound 时 SecItemAdd 新增
    func save(_ data: Data, account: String) throws {
        // 超过 1MB 硬阈值直接判容量不足（实际限制视设备而定）
        guard data.count <= maxItemSizeBytes else {
            throw BackupError.insufficientSpace
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 已有条目 → 原地更新
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw BackupError.writeFailed(Int(updateStatus))
        }

        // 条目不存在 → 新增
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return }
        if addStatus == errSecDuplicateItem {
            // 竞态下条目已被并发写入：回退为更新
            let retryStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttributes as CFDictionary)
            guard retryStatus == errSecSuccess else {
                throw BackupError.writeFailed(Int(retryStatus))
            }
            return
        }
        throw BackupError.writeFailed(Int(addStatus))
    }

    /// 通用读取（kSecMatchLimitOne）
    func load(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw BackupError.itemNotFound }
            throw BackupError.readFailed(Int(status))
        }
        guard let data = result as? Data else { throw BackupError.dataCorrupted }
        return data
    }

    /// 通用删除（条目不存在视为成功）
    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BackupError.writeFailed(Int(status))
        }
    }
}
