#pragma once

#include <QDialog>

#include <array>
#include <memory>

class QCheckBox;
class QComboBox;
class QDateTimeEdit;
class QDoubleSpinBox;
class QLineEdit;

namespace tick {

class TaskItem;

// 任务编辑对话框：新建 / 编辑 任务的全部属性
// - 类型（单项 / 进度）、状态、进度总量/当前值
// - 颜色（继承父级 / 预设色板）、起止日期（继承父级 / 自设）
// - 提醒时间 + 重复规则（不重复 / 每天 / 每周 / 每月 / 自定义周几）
class TaskDialog : public QDialog {
    Q_OBJECT
public:
    explicit TaskDialog(QWidget* parent = nullptr);

    /// 用现有任务初始化（编辑）；item 为 nullptr 时新建
    void setup(const std::shared_ptr<TaskItem>& item);

    /// 返回被编辑的任务（新建时返回新任务；仅在 accepted 后有效）
    std::shared_ptr<TaskItem> item() const { return item_; }

    void reapplyLanguage();

private slots:
    void onAccept();
    void onTypeChanged();
    void onRepeatChanged();
    void onReminderToggled(bool on);

private:
    void syncReminderEnabled();
    std::vector<int> selectedWeekdays() const;

    QLineEdit* nameEdit_ = nullptr;
    QComboBox* typeCombo_ = nullptr;
    QComboBox* colorCombo_ = nullptr;
    QComboBox* statusCombo_ = nullptr;
    QDoubleSpinBox* totalSpin_ = nullptr;
    QDoubleSpinBox* currentSpin_ = nullptr;
    QCheckBox* startEnable_ = nullptr;
    QDateTimeEdit* startEdit_ = nullptr;
    QCheckBox* endEnable_ = nullptr;
    QDateTimeEdit* endEdit_ = nullptr;

    QCheckBox* reminderEnable_ = nullptr;
    QDateTimeEdit* reminderEdit_ = nullptr;
    QComboBox* repeatCombo_ = nullptr;
    std::array<QCheckBox*, 7> weekdayChecks_{};

    std::shared_ptr<TaskItem> item_;
};

} // namespace tick