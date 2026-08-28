#include "ui/taskdialog.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDateTimeEdit>
#include <QDialogButtonBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLineEdit>
#include <QStringList>
#include <QVBoxLayout>

#include <algorithm>
#include <vector>

#include "model/taskitem.h"
#include "ui/theme.h"
#include "ui/translation.h"

namespace tick {

TaskDialog::TaskDialog(QWidget* parent)
    : QDialog(parent), item_(std::make_shared<TaskItem>()) {
    setModal(true);
    setMinimumWidth(400);

    nameEdit_ = new QLineEdit(this);

    typeCombo_ = new QComboBox(this);
    typeCombo_->addItem(TR("单项", "Single"), taskTypeToString(TaskType::Single));
    typeCombo_->addItem(TR("进度", "Progress"), taskTypeToString(TaskType::Progress));

    colorCombo_ = new QComboBox(this);
    colorCombo_->addItem(TR("继承父级", "Inherit"), QString());
    const auto& palette = goalColorPalette();
    for (const auto& c : palette) {
        colorCombo_->addItem(c.name, c.hex);
    }

    statusCombo_ = new QComboBox(this);
    statusCombo_->addItem(TR("未完成", "Not done"), taskStatusToString(TaskStatus::NotDone));
    statusCombo_->addItem(TR("半完成", "Half done"), taskStatusToString(TaskStatus::HalfDone));
    statusCombo_->addItem(TR("完成", "Done"), taskStatusToString(TaskStatus::Done));
    statusCombo_->addItem(TR("删除", "Deleted"), taskStatusToString(TaskStatus::Deleted));

    totalSpin_ = new QDoubleSpinBox(this);
    totalSpin_->setRange(0.0, 1000000.0);
    totalSpin_->setDecimals(1);
    currentSpin_ = new QDoubleSpinBox(this);
    currentSpin_->setRange(0.0, 1000000.0);
    currentSpin_->setDecimals(1);

    startEnable_ = new QCheckBox(this);
    startEdit_ = new QDateTimeEdit(QDateTime::currentDateTime(), this);
    startEdit_->setCalendarPopup(true);
    startEdit_->setDisplayFormat(QStringLiteral("yyyy-MM-dd HH:mm"));
    endEnable_ = new QCheckBox(this);
    endEdit_ = new QDateTimeEdit(QDateTime::currentDateTime(), this);
    endEdit_->setCalendarPopup(true);
    endEdit_->setDisplayFormat(QStringLiteral("yyyy-MM-dd HH:mm"));

    reminderEnable_ = new QCheckBox(this);
    reminderEdit_ = new QDateTimeEdit(QDateTime::currentDateTime(), this);
    reminderEdit_->setCalendarPopup(true);
    reminderEdit_->setDisplayFormat(QStringLiteral("yyyy-MM-dd HH:mm"));
    repeatCombo_ = new QComboBox(this);
    repeatCombo_->addItem(TR("不重复", "Never"), repeatRuleToString(RepeatRule::Never));
    repeatCombo_->addItem(TR("每天", "Daily"), repeatRuleToString(RepeatRule::Daily));
    repeatCombo_->addItem(TR("每周", "Weekly"), repeatRuleToString(RepeatRule::Weekly));
    repeatCombo_->addItem(TR("每月", "Monthly"), repeatRuleToString(RepeatRule::Monthly));
    repeatCombo_->addItem(TR("自定义", "Custom"), repeatRuleToString(RepeatRule::Custom));
    // 自定义周几（raw 1=周日…7=周六）
    const QStringList dayNames = {
        TR("周日", "Sun"), TR("周一", "Mon"), TR("周二", "Tue"), TR("周三", "Wed"),
        TR("周四", "Thu"), TR("周五", "Fri"), TR("周六", "Sat"),
    };
    auto weekLayout = new QHBoxLayout;
    for (int i = 0; i < 7; ++i) {
        weekdayChecks_[i] = new QCheckBox(dayNames[i], this);
        weekLayout->addWidget(weekdayChecks_[i]);
    }

    auto form = new QFormLayout;
    form->addRow(TR("名称", "Name"), nameEdit_);
    form->addRow(TR("类型", "Type"), typeCombo_);
    form->addRow(TR("颜色", "Color"), colorCombo_);
    form->addRow(TR("状态", "Status"), statusCombo_);
    form->addRow(TR("总量", "Total amount"), totalSpin_);
    form->addRow(TR("当前进度", "Current progress"), currentSpin_);
    form->addRow(startEnable_, startEdit_);
    form->addRow(endEnable_, endEdit_);
    form->addRow(reminderEnable_, reminderEdit_);
    form->addRow(TR("重复规则", "Repeat"), repeatCombo_);
    form->addRow(QString(), weekLayout);

    auto buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    auto root = new QVBoxLayout(this);
    root->addLayout(form);
    root->addWidget(buttons);

    connect(typeCombo_, QOverload<int>::of(&QComboBox::currentIndexChanged), this, &TaskDialog::onTypeChanged);
    connect(repeatCombo_, QOverload<int>::of(&QComboBox::currentIndexChanged), this, &TaskDialog::onRepeatChanged);
    connect(reminderEnable_, &QCheckBox::toggled, this, &TaskDialog::onReminderToggled);
    connect(buttons, &QDialogButtonBox::accepted, this, &TaskDialog::onAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &TaskDialog::reject);

    onTypeChanged();
    onRepeatChanged();
    syncReminderEnabled();
}

void TaskDialog::setup(const std::shared_ptr<TaskItem>& item) {
    item_ = item ? item : std::make_shared<TaskItem>();
    nameEdit_->setText(item_->name);
    const int tIdx = typeCombo_->findData(taskTypeToString(item_->type));
    typeCombo_->setCurrentIndex(tIdx < 0 ? 0 : tIdx);
    const QString hex = item_->colorHex.has_value() ? QString::fromStdString(*item_->colorHex) : QString();
    const int cIdx = colorCombo_->findData(hex);
    colorCombo_->setCurrentIndex(cIdx < 0 ? 0 : cIdx);
    const int sIdx = statusCombo_->findData(taskStatusToString(item_->status));
    statusCombo_->setCurrentIndex(sIdx < 0 ? 0 : sIdx);
    totalSpin_->setValue(item_->totalAmount);
    currentSpin_->setValue(item_->currentAmount);
    startEnable_->setChecked(item_->startDate.has_value());
    if (item_->startDate.has_value()) startEdit_->setDateTime(*item_->startDate);
    endEnable_->setChecked(item_->endDate.has_value());
    if (item_->endDate.has_value()) endEdit_->setDateTime(*item_->endDate);
    reminderEnable_->setChecked(item_->reminderDate.has_value());
    if (item_->reminderDate.has_value()) reminderEdit_->setDateTime(*item_->reminderDate);
    const int rIdx = repeatCombo_->findData(repeatRuleToString(item_->repeatRule));
    repeatCombo_->setCurrentIndex(rIdx < 0 ? 0 : rIdx);
    const auto wds = item_->effectiveWeekdays();
    for (int raw : wds) {
        if (raw >= 1 && raw <= 7) weekdayChecks_[raw - 1]->setChecked(true);
    }
    onTypeChanged();
    onRepeatChanged();
    syncReminderEnabled();
    reapplyLanguage();
}

void TaskDialog::onTypeChanged() {
    const QString type = typeCombo_->currentData().toString();
    const bool isProgress = (type == taskTypeToString(TaskType::Progress));
    statusCombo_->setVisible(!isProgress);
    totalSpin_->setVisible(isProgress);
    currentSpin_->setVisible(isProgress);
}

void TaskDialog::onRepeatChanged() {
    const QString rule = repeatCombo_->currentData().toString();
    const bool isCustom = (rule == repeatRuleToString(RepeatRule::Custom));
    for (auto* c : weekdayChecks_) c->setVisible(isCustom);
}

void TaskDialog::onReminderToggled(bool on) {
    reminderEdit_->setEnabled(on);
    repeatCombo_->setEnabled(on);
}

void TaskDialog::syncReminderEnabled() {
    const bool on = reminderEnable_->isChecked();
    reminderEdit_->setEnabled(on);
    repeatCombo_->setEnabled(on);
}

std::vector<int> TaskDialog::selectedWeekdays() const {
    std::vector<int> out;
    for (int i = 0; i < 7; ++i) {
        if (weekdayChecks_[i]->isChecked()) out.push_back(i + 1);
    }
    return out;
}

void TaskDialog::onAccept() {
    if (nameEdit_->text().trimmed().isEmpty()) {
        nameEdit_->setFocus();
        return;
    }
    item_->name = nameEdit_->text().trimmed();
    item_->type = taskTypeFromString(typeCombo_->currentData().toString());
    const QString hex = colorCombo_->currentData().toString();
    item_->colorHex = hex.isEmpty() ? std::nullopt : std::optional<std::string>(hex.toStdString());
    if (item_->type == TaskType::Single) {
        item_->status = taskStatusFromString(statusCombo_->currentData().toString());
    } else {
        item_->totalAmount = std::max(0.0, totalSpin_->value());
        item_->currentAmount = std::min(std::max(currentSpin_->value(), 0.0), item_->totalAmount);
    }
    item_->startDate = startEnable_->isChecked() ? std::optional<QDateTime>(startEdit_->dateTime()) : std::nullopt;
    item_->endDate = endEnable_->isChecked() ? std::optional<QDateTime>(endEdit_->dateTime()) : std::nullopt;
    item_->reminderDate = reminderEnable_->isChecked()
                              ? std::optional<QDateTime>(reminderEdit_->dateTime())
                              : std::nullopt;
    item_->repeatRule = repeatRuleFromString(repeatCombo_->currentData().toString());
    if (item_->repeatRule == RepeatRule::Custom) {
        QStringList parts;
        for (int w : selectedWeekdays()) parts << QString::number(w);
        item_->customWeekdaysRaw = parts.isEmpty()
                                       ? std::nullopt
                                       : std::optional<std::string>(parts.join(QLatin1Char(',')).toStdString());
    } else {
        item_->customWeekdaysRaw = std::nullopt;
    }
    accept();
}

void TaskDialog::reapplyLanguage() {
    setWindowTitle(TR("任务", "Task"));
    startEnable_->setText(TR("开始日期", "Start date"));
    endEnable_->setText(TR("截止日期", "Due date"));
    reminderEnable_->setText(TR("提醒", "Reminder"));
    totalSpin_->setSuffix(QString());
    currentSpin_->setSuffix(QString());
}

} // namespace tick