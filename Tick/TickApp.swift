import SwiftUI
import SwiftData

@main
struct TickApp: App {
    /// 全局设置（配色 / 语言 / iCloud 同步）
    @StateObject private var settings = SettingsStore.shared

    /// 本地持久化容器（SwiftData）
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Goal.self, TaskItem.self)
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
        // 通知代理：处理提醒点击跳转
        NotificationService.shared.setDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
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
