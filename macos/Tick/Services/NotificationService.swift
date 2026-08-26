import Foundation
import UserNotifications

/// 通知点击后的跳转目标
struct ReminderTarget: Equatable {
    let taskID: UUID
    let goalID: UUID
}

/// 本地通知服务：提醒注册、取消、点击跳转
/// （@Published 属性均保证在主线程更新，故可安全标记 Sendable）
final class NotificationService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = NotificationService()

    /// 通知点击后待处理的跳转目标（主界面观察并定位）
    @Published var pendingTarget: ReminderTarget?
    /// 权限状态（供 UI 降级提示）
    @Published var authorizationDenied = false

    private override init() {
        super.init()
    }

    // MARK: - 代理与权限

    /// 设置通知中心代理（App 启动时调用一次）
    func setDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// 请求通知权限，返回是否授权
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await MainActor.run { authorizationDenied = !granted }
        return granted
    }

    /// 刷新权限状态（更新 authorizationDenied）
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let denied = settings.authorizationStatus == .denied
        await MainActor.run { authorizationDenied = denied }
    }

    // MARK: - 提醒注册 / 取消

    /// 为任务注册提醒：先取消旧请求，再按重复规则逐条添加
    func scheduleReminder(for task: TaskItem, goalName: String) async {
        // 提取模型数据，避免跨挂起点访问 SwiftData 模型对象
        let taskID = task.id
        let taskName = task.name
        let weekdays = task.effectiveWeekdays()
        let rule = task.repeatRule
        let reminderDate = task.reminderDate
        let goalID = Self.owningGoal(of: task)?.id

        // 幂等：先清理该任务已有提醒
        cancelReminders(taskID: taskID)

        // 无提醒时间、或未归属目标（无法定位跳转）时不注册
        guard let date = reminderDate, let goalID else { return }
        // 重复规则缺省视为不重复
        let effectiveRule = rule ?? .never
        let repeats = effectiveRule != .never

        let center = UNUserNotificationCenter.current()
        for placement in Self.triggerPlacements(rule: effectiveRule,
                                                date: date,
                                                weekdays: weekdays,
                                                taskID: taskID) {
            let content = UNMutableNotificationContent()
            content.title = taskName
            content.body = "目标：\(goalName)"
            content.sound = .default
            // 携带标识，用于点击通知后跳转
            content.userInfo = [
                "taskID": taskID.uuidString,
                "goalID": goalID.uuidString
            ]
            let trigger = UNCalendarNotificationTrigger(dateMatching: placement.components, repeats: repeats)
            let request = UNNotificationRequest(identifier: placement.identifier,
                                                content: content,
                                                trigger: trigger)
            try? await center.add(request)
        }
    }

    /// 取消任务全部提醒（含自定义周几的多条请求）
    func cancelReminders(taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: Self.identifiers(for: taskID))
    }

    // MARK: - 纯逻辑（可测试）

    /// 根据重复规则生成通知触发器组件与标识符
    /// （repeats 由调用方判定：never 为 false，其余为 true）
    static func triggerPlacements(rule: RepeatRule,
                                   date: Date,
                                   weekdays: [Int],
                                   taskID: UUID) -> [(identifier: String, components: DateComponents)] {
        let calendar = Calendar.current
        let base = taskID.uuidString

        switch rule {
        case .never:
            // 一次性：精确到年月日时分
            var comps = timeComponents(of: date, calendar: calendar)
            comps.year = calendar.component(.year, from: date)
            comps.month = calendar.component(.month, from: date)
            comps.day = calendar.component(.day, from: date)
            return [(identifier: base, components: comps)]
        case .daily:
            // 每天：仅时分
            return [(identifier: base, components: timeComponents(of: date, calendar: calendar))]
        case .weekly:
            // 每周：星期几 + 时分
            var comps = timeComponents(of: date, calendar: calendar)
            comps.weekday = calendar.component(.weekday, from: date)
            return [(identifier: base, components: comps)]
        case .monthly:
            // 每月：几号 + 时分（不含 month，实现跨月重复）
            var comps = timeComponents(of: date, calendar: calendar)
            comps.day = calendar.component(.day, from: date)
            return [(identifier: base, components: comps)]
        case .custom:
            // 过滤非法值并有序去重（1=周日…7=周六）
            var seen = Set<Int>()
            let valid = weekdays.filter { (1...7).contains($0) && seen.insert($0).inserted }
            // 未选择周几时回退为每天
            guard !valid.isEmpty else {
                return [(identifier: base, components: timeComponents(of: date, calendar: calendar))]
            }
            return valid.map { weekday in
                var comps = timeComponents(of: date, calendar: calendar)
                comps.weekday = weekday
                return (identifier: "\(base)-w\(weekday)", components: comps)
            }
        }
    }

    /// 任务可能产生的全部通知标识符（基础 id + 自定义周几 7 个变体）
    static func identifiers(for taskID: UUID) -> [String] {
        let base = taskID.uuidString
        return [base] + (1...7).map { "\(base)-w\($0)" }
    }

    /// 提取时分组件（每次新建，DateComponents 为引用类型）
    private static func timeComponents(of date: Date, calendar: Calendar) -> DateComponents {
        var comps = DateComponents()
        comps.hour = calendar.component(.hour, from: date)
        comps.minute = calendar.component(.minute, from: date)
        return comps
    }

    /// 沿父链向上定位任务所属目标
    private static func owningGoal(of task: TaskItem) -> Goal? {
        var current: TaskItem? = task
        while let node = current {
            if let goal = node.goal { return goal }
            current = node.parentTask
        }
        return nil
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    /// 前台展示：横幅、列表、声音
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// 点击通知：解析 userInfo 中的 taskID/goalID 生成跳转目标
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        let info = response.notification.request.content.userInfo
        guard let taskID = (info["taskID"] as? String).flatMap(UUID.init(uuidString:)),
              let goalID = (info["goalID"] as? String).flatMap(UUID.init(uuidString:)) else {
            return
        }
        // 主线程更新，供 SwiftUI 主界面安全观察
        DispatchQueue.main.async {
            self.pendingTarget = ReminderTarget(taskID: taskID, goalID: goalID)
        }
    }
}
