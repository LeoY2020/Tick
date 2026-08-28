#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QVector>

#include <memory>
#include <optional>
#include <vector>

#include "model/goal.h"
#include "model/taskitem.h"

namespace tick {

// 本地通知服务：进程内轮询提醒（提醒时间 + 重复规则），
// 使用 QSystemTrayIcon::showMessage 展示（无系统托盘时回退 QMessageBox）。
class NotificationService : public QObject {
    Q_OBJECT
public:
    explicit NotificationService(QObject* parent = nullptr);

    void setEnabled(bool enabled);
    bool enabled() const;

    /// 基于目标全集重建提醒调度
    void reschedule(const std::vector<std::shared_ptr<Goal>>& goals);

    /// 展示通知（系统托盘弹气泡；无托盘时回退消息框）
    void showNotification(const QString& summary, const QString& body);

    /// 纯逻辑：给定当前时刻，计算下一次提醒（Never 返回 base，recurring 返回下一次重复）
    static std::optional<QDateTime> nextReminder(const TaskItem& task, const QDateTime& now);

private slots:
    void poll();

private:
    struct Reminder {
        QString id;
        QString title;
        QString body;
        QDateTime nextFire;
        RepeatRule rule = RepeatRule::Never;
        std::vector<int> weekdays;
    };

    // 基于上一次触发时刻，计算下一次重复触发（Never 返回 nullopt）
    static std::optional<QDateTime> advance(const QDateTime& current, RepeatRule rule,
                                            const std::vector<int>& weekdays);

    void collect(const std::shared_ptr<Goal>& goal, const QString& goalName);

    QTimer timer_;
    bool enabled_ = false;
    QVector<Reminder> reminders_;
    QSystemTrayIcon* trayIcon_ = nullptr;
};

} // namespace tick