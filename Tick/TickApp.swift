import SwiftUI
import SwiftData

@main
struct TickApp: App {
    /// 全局设置（配色 / 语言 / iCloud 同步）
    @StateObject private var settings = SettingsStore.shared
    /// CloudKit 同步管理器：iCloud 开关切换时重建 ModelContainer
    @StateObject private var cloudSync = CloudSyncManager.shared

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

/// 语言环境修饰器：locale 非 nil 时覆盖环境（切换立即生效），nil 时跟随系统
private struct LocaleModifier: ViewModifier {
    let locale: Locale?

    func body(content: Content) -> some View {
        if let locale {
            content.environment(\.locale, locale)
        } else {
            content
        }
    }
}
