#include "services/notificationservice.h"

#include <QDate>
#include <QIcon>
#include <QMessageBox>
#include <QPainter>
#include <QPixmap>
#include <QStringList>

namespace tick {

namespace {

// customWeekdaysRaw 的星期语义（1=周日…7=周六）→ Qt 的 dayOfWeek（1=周一…7=周日）
int toQtWeekday(int raw) {
    return ((raw + 5) % 7) + 1;
}

// Qt 的 dayOfWeek → raw（自定义星期原始语义）
int fromQtWeekday(int qt) {
    return qt == 7 ? 1 : qt + 1;
}

// 生成一个简单的托盘图标（彩色原点），无外部资源依赖
QIcon makeTrayIcon() {
    QPixmap pm(22, 22);
    pm.fill(Qt::transparent);
    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing);
    p.setBrush(QColor(QStringLiteral("#007AFF")));
    p.setPen(Qt::NoPen);
    p.drawEllipse(1, 1, 20, 20);
    p.setBrush(Qt::white);
    p.drawEllipse(7, 7, 8, 8);
    p.end();
    return QIcon(pm);
}

} // namespace

NotificationService::NotificationService(QObject* parent) : QObject(parent) {
    timer_.setInterval(60 * 1000);
    connect(&timer_, &QTimer::timeout, this, &NotificationService::poll);
    trayIcon_ = new QSystemTrayIcon(makeTrayIcon(), this);
    trayIcon_->setToolTip(QStringLiteral("Tick"));
}

void NotificationService::setEnabled(bool enabled) {
    enabled_ = enabled;
    if (enabled_) {
        if (!timer_.isActive()) timer_.start();
        if (QSystemTrayIcon::isSystemTrayAvailable() && !trayIcon_->isVisible()) {
            trayIcon_->show();
        }
    } else {
        timer_.stop();
        reminders_.clear();
    }
}

bool NotificationService::enabled() const {
    return enabled_;
}

void NotificationService::reschedule(const std::vector<std::shared_ptr<Goal>>& goals) {
    reminders_.clear();
    for (const auto& g : goals) {
        collect(g, g->name);
    }
    if (enabled_ && !timer_.isActive()) timer_.start();
}

void NotificationService::collect(const std::shared_ptr<Goal>& goal, const QString& goalName) {
    if (!goal) return;
    for (const auto& t : goal->tasks) {
        if (!t) continue;
        if (!t->reminderDate.has_value()) continue;
        // 删除态不提醒
        if (t->type == TaskType::Single && t->status == TaskStatus::Deleted) continue;

        Reminder r;
        r.id = QString::fromStdString(t->id);
        r.title = t->name;
        r.body = QStringLiteral("目标：%1").arg(goalName);
        r.nextFire = *t->reminderDate;
        r.rule = t->repeatRule;
        r.weekdays = t->effectiveWeekdays();
        reminders_.push_back(r);
    }
}

std::optional<QDateTime> NotificationService::advance(const QDateTime& current, RepeatRule rule,
                                                     const std::vector<int>& weekdays) {
    switch (rule) {
        case RepeatRule::Never:
            return std::nullopt;
        case RepeatRule::Daily:
            return current.addDays(1);
        case RepeatRule::Weekly:
            return current.addDays(7);
        case RepeatRule::Monthly:
            return current.addMonths(1);
        case RepeatRule::Custom: {
            if (weekdays.empty()) return current.addDays(1);
            // 从次日开始找下一个匹配的星期
            for (int offset = 1; offset <= 7; ++offset) {
                const QDate d = current.date().addDays(offset);
                const int qt = d.dayOfWeek();
                const int raw = fromQtWeekday(qt);
                for (int w : weekdays) {
                    if (w == raw) {
                        return QDateTime(d, current.time());
                    }
                }
            }
            // 兜底（理论不会到达）
            return current.addDays(1);
        }
    }
    return std::nullopt;
}

std::optional<QDateTime> NotificationService::nextReminder(const TaskItem& task, const QDateTime& now) {
    if (!task.reminderDate.has_value()) return std::nullopt;
    const QDateTime base = *task.reminderDate;

    if (task.repeatRule == RepeatRule::Never) {
        return base;
    }
    if (base >= now) {
        return base;
    }
    // 初次已错过：从 base 逐次推进到不早于 now
    QDateTime cur = base;
    for (int i = 0; i < 800; ++i) { // 防止死循环
        auto nxt = advance(cur, task.repeatRule, task.effectiveWeekdays());
        if (!nxt.has_value()) return std::nullopt;
        cur = *nxt;
        if (cur >= now) return cur;
    }
    return std::nullopt;
}

void NotificationService::poll() {
    if (!enabled_) return;
    const QDateTime now = QDateTime::currentDateTime();
    for (int i = reminders_.size() - 1; i >= 0; --i) {
        Reminder& r = reminders_[i];
        if (r.nextFire <= now) {
            showNotification(r.title, r.body);
            if (r.rule == RepeatRule::Never) {
                reminders_.removeAt(i);
                continue;
            }
            auto nxt = advance(r.nextFire, r.rule, r.weekdays);
            if (nxt.has_value()) {
                r.nextFire = *nxt;
            } else {
                reminders_.removeAt(i);
            }
        }
    }
}

void NotificationService::showNotification(const QString& summary, const QString& body) {
    // 优先用系统托盘气泡
    if (QSystemTrayIcon::supportsMessages() && trayIcon_->isVisible()) {
        trayIcon_->showMessage(summary, body, QSystemTrayIcon::Information, 5000);
        return;
    }
    // 无可用系统托盘/不支持气泡时回退消息框
    QMessageBox::information(nullptr, summary, body);
}

} // namespace tick