import SwiftUI
import SwiftData

@main
struct TickApp: App {
    /// 全局设置（配色 / 语言 / iCloud 同步）
    @StateObject private var settings = SettingsStore.shared
    /// CloudKit 同步管理器：iCloud 开关切换时重建 ModelContainer
    @StateObject private var cloudSync = CloudSyncManager.shared

    init() {
        // 启动即设置通知代理：冷启动（点击通知拉起 App）时 didReceive 回调可达
        NotificationService.shared.setDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 同步开关切换后 container 重建，SwiftUI 自动重挂载新容器
                .modelContainer(cloudSync.container)
                .environmentObject(settings)
                .preferredColorScheme(settings.preferredColorScheme)
                .modifier(LocaleModifier(locale: settings.currentLocale))
        }
    }
}

/// 语言环境修饰器：locale 非 nil 时覆盖环境（切换立即生效），nil 时跟随系统。
/// 注意结构恒定：不能使用 if/else 分支——"跟随系统"(nil) ↔ 具体语言切换时
/// 分支切换会改变子树结构性 identity，导致 ContentView 的 @State 被销毁重建
/// （selectedGoal 归 nil → 界面无限转圈）。故 nil 时以环境当前 locale 等值回写。
private struct LocaleModifier: ViewModifier {
    let locale: Locale?
    @Environment(\.locale) private var systemLocale

    func body(content: Content) -> some View {
        content.environment(\.locale, locale ?? systemLocale)
    }
}
