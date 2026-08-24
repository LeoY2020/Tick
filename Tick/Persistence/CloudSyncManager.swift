import Foundation
import SwiftData
import CloudKit
import UserNotifications

/// CloudKit 同步管理器：iCloud 开关切换、容器重建、云端账户状态。
///
/// 同步机制说明（SwiftData + CloudKit 框架内置行为）：
/// - 开启同步：本地数据由 SwiftData 自动增量推送至 CloudKit 私有库
/// - 合并策略：云端已有同账户数据（如另一台设备产生）按 Last Write Wins 合并（框架行为）
/// - 重装恢复：卸载重装并登录同一 Apple ID 后，自动从 CloudKit 拉取恢复全部数据
@MainActor
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    /// CloudKit 容器标识（主代理需在开发者后台 / entitlements 中配置同名容器）
    private static let containerID = "iCloud.com.tick.app"

    /// 当前激活的 ModelContainer（同步开关切换后重建）
    @Published private(set) var container: ModelContainer
    /// iCloud 账户可用性（CKContainer.accountStatus == .available）
    @Published private(set) var cloudAvailable = false
    /// 容器重建中（切换开关时 UI 指示）
    @Published private(set) var isRebuilding = false

    /// 按当前 SettingsStore.shared.iCloudSyncEnabled 创建初始容器
    init() {
        container = Self.buildContainer(enabled: SettingsStore.shared.iCloudSyncEnabled)
    }

    /// 生成当前同步开关对应的持久化配置：
    /// 开启 → CloudKit 私有库；关闭 → 本地 SQLite（默认 Application Support 目录）。
    /// 本地配置显式传 .none，确保应用具备 CloudKit entitlement 时关闭开关仍为纯本地存储
    func makeConfiguration() -> ModelConfiguration {
        Self.makeConfiguration(enabled: SettingsStore.shared.iCloudSyncEnabled)
    }

    /// 开关切换：重建容器（local → CloudKit / CloudKit → local）。
    /// 内部同步持久化 SettingsStore，保证调用一次即完整生效。
    /// 注意：容器切换后 UI 层需以 .modelContainer(container) 重新挂载新容器（TickApp 接入）
    func applySyncSetting(enabled: Bool) {
        // 持久化开关（SettingsStore didSet 负责本地 + Keychain 备份 + iCloud KVS 写入）
        SettingsStore.shared.iCloudSyncEnabled = enabled

        isRebuilding = true
        container = Self.buildContainer(enabled: enabled)
        isRebuilding = false
    }

    /// 刷新 iCloud 账户状态：
    /// .available → true；其他（.noAccount / .restricted / .couldNotDetermine / .temporarilyUnavailable）及查询失败 → false
    func refreshAccountStatus() async {
        let status: CKAccountStatus
        do {
            status = try await CKContainer(identifier: Self.containerID).accountStatus()
        } catch {
            cloudAvailable = false
            return
        }
        cloudAvailable = (status == .available)
    }

    // MARK: - 私有构建

    /// 生成指定模式下的 ModelConfiguration
    private static func makeConfiguration(enabled: Bool) -> ModelConfiguration {
        if enabled {
            // 显式指定私有 CloudKit 库；store 路径由框架管理
            return ModelConfiguration(cloudKitDatabase: .private(containerID))
        } else {
            // 本地 SQLite（框架默认存储于 Application Support）
            return ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }
    }

    /// 统一容器构建：按 enabled 创建；失败（无 entitlement / 容器不可用等）回退本地配置重试；仍失败 fatalError
    private static func buildContainer(enabled: Bool) -> ModelContainer {
        let schema = Schema([Goal.self, TaskItem.self])
        do {
            return try ModelContainer(for: schema, configurations: [makeConfiguration(enabled: enabled)])
        } catch {
            do {
                return try ModelContainer(for: schema, configurations: [makeConfiguration(enabled: false)])
            } catch {
                fatalError("无法创建 ModelContainer（本地回退亦失败）: \(error)")
            }
        }
    }
}