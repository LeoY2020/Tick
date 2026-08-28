#include "ui/goaldialog.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDateTimeEdit>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QLineEdit>
#include <QVBoxLayout>

#include "model/enums.h"
#include "model/goal.h"
#include "ui/theme.h"
#include "ui/translation.h"

namespace tick {

GoalDialog::GoalDialog(QWidget* parent)
    : QDialog(parent), item_(std::make_shared<Goal>()) {
    setModal(true);
    setMinimumWidth(380);

    nameEdit_ = new QLineEdit(this);

    colorCombo_ = new QComboBox(this);
    colorCombo_->addItem(TR("跟随系统", "Auto"), QStringLiteral("auto"));
    const auto& palette = goalColorPalette();
    for (const auto& c : palette) {
        colorCombo_->addItem(c.name, c.hex);
    }

    iconEdit_ = new QLineEdit(this);
    iconEdit_->setPlaceholderText(TR("可选", "Optional"));

    startEnable_ = new QCheckBox(this);
    startEdit_ = new QDateTimeEdit(QDateTime::currentDateTime(), this);
    startEdit_->setCalendarPopup(true);
    startEdit_->setDisplayFormat(QStringLiteral("yyyy-MM-dd HH:mm"));
    startPrecise_ = new QCheckBox(TR("精确到小时", "Precise to hour"), this);

    endEnable_ = new QCheckBox(this);
    endEdit_ = new QDateTimeEdit(QDateTime::currentDateTime(), this);
    endEdit_->setCalendarPopup(true);
    endEdit_->setDisplayFormat(QStringLiteral("yyyy-MM-dd HH:mm"));
    endPrecise_ = new QCheckBox(TR("精确到小时", "Precise to hour"), this);

    modeCombo_ = new QComboBox(this);
    modeCombo_->addItem(TR("全部任务", "All tasks"), countingModeToString(ProgressCountingMode::AllTasks));
    modeCombo_->addItem(TR("仅叶子任务", "Leaf tasks only"), countingModeToString(ProgressCountingMode::LeafTasks));

    auto form = new QFormLayout;
    form->addRow(TR("名称", "Name"), nameEdit_);
    form->addRow(TR("颜色", "Color"), colorCombo_);
    form->addRow(TR("图标", "Icon"), iconEdit_);

    auto startLayout = new QFormLayout;
    startLayout->addRow(TR("开始日期", "Start date"), startEdit_);
    startLayout->addRow(QString(), startPrecise_);
    auto startBox = new QVBoxLayout;
    startBox->setContentsMargins(0, 0, 0, 0);
    startBox->addLayout(startLayout);
    auto startRow = new QWidget(this);
    startRow->setLayout(startBox);
    form->addRow(startEnable_, startRow);

    auto endLayout = new QFormLayout;
    endLayout->addRow(TR("截止日期", "Due date"), endEdit_);
    endLayout->addRow(QString(), endPrecise_);
    auto endBox = new QVBoxLayout;
    endBox->setContentsMargins(0, 0, 0, 0);
    endBox->addLayout(endLayout);
    auto endRow = new QWidget(this);
    endRow->setLayout(endBox);
    form->addRow(endEnable_, endRow);

    form->addRow(TR("进度统计", "Progress counting"), modeCombo_);

    auto buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);

    auto root = new QVBoxLayout(this);
    root->addLayout(form);
    root->addWidget(buttons);

    connect(startEnable_, &QCheckBox::toggled, this, &GoalDialog::syncDateEnabled);
    connect(endEnable_, &QCheckBox::toggled, this, &GoalDialog::syncDateEnabled);
    connect(buttons, &QDialogButtonBox::accepted, this, &GoalDialog::onAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &GoalDialog::onRejected);

    syncDateEnabled();
}

void GoalDialog::setup(const std::shared_ptr<Goal>& item) {
    item_ = item ? item : std::make_shared<Goal>();
    nameEdit_->setText(item_->name);
    const QString curColor = QString::fromStdString(item_->colorHex);
    const int idx = colorCombo_->findData(curColor);
    colorCombo_->setCurrentIndex(idx < 0 ? 0 : idx);
    iconEdit_->setText(QString::fromStdString(item_->iconSystemName.value_or("")));
    startEnable_->setChecked(item_->startDate.has_value());
    if (item_->startDate.has_value()) startEdit_->setDateTime(*item_->startDate);
    startPrecise_->setChecked(item_->startDatePreciseToHour);
    endEnable_->setChecked(item_->endDate.has_value());
    if (item_->endDate.has_value()) endEdit_->setDateTime(*item_->endDate);
    endPrecise_->setChecked(item_->endDatePreciseToHour);
    const int mIdx = modeCombo_->findData(countingModeToString(item_->progressCountingMode));
    modeCombo_->setCurrentIndex(mIdx < 0 ? 0 : mIdx);
    syncDateEnabled();
    reapplyLanguage();
}

void GoalDialog::syncDateEnabled() {
    startEdit_->setEnabled(startEnable_->isChecked());
    startPrecise_->setEnabled(startEnable_->isChecked());
    endEdit_->setEnabled(endEnable_->isChecked());
    endPrecise_->setEnabled(endEnable_->isChecked());
}

void GoalDialog::onAccept() {
    if (nameEdit_->text().trimmed().isEmpty()) {
        nameEdit_->setFocus();
        return;
    }
    item_->name = nameEdit_->text().trimmed();
    item_->colorHex = colorCombo_->currentData().toString().toStdString();
    const QString icon = iconEdit_->text().trimmed();
    item_->iconSystemName = icon.isEmpty() ? std::nullopt : std::optional<std::string>(icon.toStdString());
    item_->startDate = startEnable_->isChecked() ? std::optional<QDateTime>(startEdit_->dateTime()) : std::nullopt;
    item_->startDatePreciseToHour = startPrecise_->isChecked();
    item_->endDate = endEnable_->isChecked() ? std::optional<QDateTime>(endEdit_->dateTime()) : std::nullopt;
    item_->endDatePreciseToHour = endPrecise_->isChecked();
    item_->progressCountingMode =
        countingModeFromString(modeCombo_->currentData().toString());
    accept();
}

void GoalDialog::onRejected() {
    reject();
}

void GoalDialog::reapplyLanguage() {
    setWindowTitle(TR("目标", "Goal"));
    startEnable_->setText(TR("开始日期", "Start date"));
    endEnable_->setText(TR("截止日期", "Due date"));
}

} // namespace tick