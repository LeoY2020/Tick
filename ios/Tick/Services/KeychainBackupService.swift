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
    /// 容量超限（单条目超过 Keychain 硬阈值）
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

// MARK: - 分片清单

/// 应用数据分片清单：分片写入的提交点（清单写入成功才算本次数据生效）
struct ChunkManifest: Codable {
    /// 清单格式版本
    var version: Int
    /// 分片数量（分片账号为 appData.0 … appData.<chunkCount - 1>）
    var chunkCount: Int
    /// 原始数据总字节数（拼接后校验，避免半新半旧或损坏数据被当成完整备份）
    var totalBytes: Int
}

// MARK: - Keychain 备份服务

/// Keychain 备份服务：kSecClassGenericPassword，kSecAttrAccessible = WhenUnlockedThisDeviceOnly。
/// 应用卸载后条目保留（防删除保护），重装可读取恢复。
final class KeychainBackupService {
    static let shared = KeychainBackupService()

    /// 服务名（shared 实例 = Bundle ID；测试可注入唯一值隔离条目）
    private let service: String
    /// 旧版应用数据条目账号名（Bundle ID + "appData"）：整份快照塞进单个条目。
    /// 仅保留读取兼容（升级前写入的备份仍可恢复），新写入不再使用。
    private let legacyAppDataKey: String
    /// 分片清单条目账号名（Bundle ID + "appData.meta"）：记录分片数与总字节数，作为分片写入的提交点
    private let appDataManifestKey: String
    /// 用户设置条目账号名（Bundle ID + "settings"）
    private let settingsKey: String
    /// 应用数据分片大小上限（3KB）：
    /// Keychain 单条目容量在 4KB 附近就不可靠（Apple 开发者论坛：4KB 为软上限，
    /// 4KB~16MB 区间存在 securityd 被系统终止的风险），因此把整份快照拆成多个 ≤3KB 的条目，
    /// 总容量只受设备可用存储限制，不再被单条目容量卡住。
    private let appDataChunkSize = 3_072
    /// 单条目大小硬阈值（1MB；Keychain 实际限制约 512KB~数 MB，视设备而定）
    private let maxItemSizeBytes = 1_048_576

    /// - Parameter service: 服务名，默认 `Bundle.main.bundleIdentifier ?? "com.tick.app"`
    init(service: String = Bundle.main.bundleIdentifier ?? "com.tick.app") {
        self.service = service
        legacyAppDataKey = service + "appData"
        appDataManifestKey = service + "appData.meta"
        settingsKey = service + "settings"
    }

    // MARK: - 应用数据（目标 + 任务）

    /// 写入应用数据：整份快照按 `appDataChunkSize` 切片，逐片写入 Keychain（每片 1 个条目）。
    /// 容量不再受单个条目限制（旧实现整份塞进 1 个条目，任务一多就写入失败）。
    /// 提交顺序：先写全部分片，再写清单（清单是提交点，指向本次的分片数量）……
    func saveAppData(_ data: Data) throws {
        let chunkCount = (data.count + appDataChunkSize - 1) / appDataChunkSize
        let previousCount = loadManifest()?.chunkCount ?? 0

        for index in 0..<chunkCount {
            let start = index * appDataChunkSize
            let end = min(start + appDataChunkSize, data.count)
            try save(data.subdata(in: start..<end), account: chunkKey(index))
        }

        // 提交点：清单写入后本次数据才算生效
        let manifest = ChunkManifest(version: 1,
                                     chunkCount: chunkCount,
                                     totalBytes: data.count)
        try save(try JSONEncoder().encode(manifest), account: appDataManifestKey)

        // ……再清理数据变短后多余的旧分片（清单已指向新数量，多余的不会被读到；
        // 清理失败不影响本次备份有效性，故不抛出）
        if previousCount > chunkCount {
            for index in chunkCount..<previousCount {
                try? delete(account: chunkKey(index))
            }
        }

        // 旧格式单条目已作废：删除，避免重装恢复时读到过期数据（失败不影响本次备份）
        try? delete(account: legacyAppDataKey)
    }

    /// 读取应用数据（无备份或读取失败返回 nil）：
    /// 有分片清单 → 按清单拼接分片（长度不符视为损坏，返回 nil）；无清单 → 兼容读取旧版单条目。
    func loadAppData() -> Data? {
        guard let manifest = loadManifest() else {
            return try? load(account: legacyAppDataKey)
        }

        var data = Data()
        data.reserveCapacity(manifest.totalBytes)
        for index in 0..<manifest.chunkCount {
            guard let chunk = try? load(account: chunkKey(index)) else { return nil }
            data.append(chunk)
        }
        // 拼接长度与清单不符 → 视为损坏（当作无备份，走正常首启流程）
        guard data.count == manifest.totalBytes else { return nil }
        return data
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

    // MARK: - 模型 API Key

    /// AI 模型 API Key 的 Keychain 账号名（service + "aiKey" + 模型原始值）
    private func aiKey(accountFor model: String) -> String {
        service + "aiKey" + model
    }

    /// 写入指定模型的 API Key（Apple Intelligence 不需要）
    func saveAPIKey(_ key: String, modelRawValue: String) throws {
        guard let data = key.data(using: .utf8) else { return }
        try save(data, account: aiKey(accountFor: modelRawValue))
    }

    /// 读取指定模型的 API Key；未配置或读取失败返回 nil
    func loadAPIKey(modelRawValue: String) -> String? {
        guard let data = try? load(account: aiKey(accountFor: modelRawValue)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 删除指定模型的 API Key（条目不存在视为成功）
    func deleteAPIKey(modelRawValue: String) {
        try? delete(account: aiKey(accountFor: modelRawValue))
    }
}

// MARK: - 通用读写

extension KeychainBackupService {

    /// 第 index 个分片的账号名
    func chunkKey(_ index: Int) -> String {
        service + "appData.\(index)"
    }

    /// 读取分片清单（无清单或解码失败返回 nil）
    func loadManifest() -> ChunkManifest? {
        guard let data = try? load(account: appDataManifestKey) else { return nil }
        return try? JSONDecoder().decode(ChunkManifest.self, from: data)
    }

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
