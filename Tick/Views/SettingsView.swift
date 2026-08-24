import SwiftUI

/// 设置界面（.sheet 弹出，Form + Section 系统设置页风格）
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var backup = DataBackupManager.shared
    @ObservedObject private var notifications = NotificationService.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                languageSection
                iCloudSection
                backupSection
                reminderSection
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .accessibilityLabel("完成")
                }
            }
        }
        // 打开设置页时刷新通知权限状态（用户可能刚从系统设置返回）
        .task { await notifications.refreshAuthorizationStatus() }
    }

    // MARK: - 外观

    /// 配色方案（分段选择：跟随系统 / 亮色 / 暗色）
    private var appearanceSection: some View {
        Section("外观") {
            Picker("配色方案", selection: $settings.colorScheme) {
                ForEach(ColorSchemeSetting.allCases) { option in
                    Text(LocalizedStringKey(option.displayName)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("配色方案")
        }
    }

    // MARK: - 语言

    /// 语言（菜单选择：跟随系统 / 简体中文 / English）
    private var languageSection: some View {
        Section("语言") {
            Picker("语言", selection: $settings.language) {
                ForEach(LanguageSetting.allCases) { option in
                    Text(LocalizedStringKey(option.displayName)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("语言")
        }
    }

    // MARK: - iCloud 同步

    /// iCloud 同步开关（持久化由 SettingsStore 的 didSet 自动处理）
    private var iCloudSection: some View {
        Section {
            Toggle("iCloud 同步", isOn: $settings.iCloudSyncEnabled)
                .accessibilityLabel("iCloud 同步")
        } header: {
            Text("iCloud")
        } footer: {
            Text("开启后数据通过 CloudKit 在设备间同步，云端合并按最后写入优先")
        }
    }

    // MARK: - 数据备份

    /// 备份状态行：成功（含时间）/ 失败 / 空间不足（附开启 iCloud 同步按钮）/ 未备份；
    /// 恢复中显示 circular 进度指示器
    private var backupSection: some View {
        Section("数据备份") {
            if backup.isRestoring {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("恢复中…")
                }
            } else {
                switch backup.status {
                case .success(let date):
                    HStack {
                        Label("备份成功", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text(date, format: .dateTime.month().day().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                case .failed(let reason):
                    HStack {
                        Label("备份失败", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Text(reason)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                case .insufficientSpace:
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Keychain 空间不足，建议开启 iCloud 同步",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("开启 iCloud 同步") {
                            settings.iCloudSyncEnabled = true
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("开启 iCloud 同步")
                    }
                case .idle:
                    Label("未备份", systemImage: "externaldrive")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 提醒（通知权限）

    /// 通知权限状态：被拒时提示并引导前往系统设置；正常显示已授权
    private var reminderSection: some View {
        Section("提醒") {
            if notifications.authorizationDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("通知权限已被拒绝，请前往系统设置开启",
                          systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Button("前往设置") { openSystemSettings() }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("前往设置")
                }
            } else {
                Label("已授权", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    /// 打开系统设置（本应用权限页）
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
