#pragma once

#include <QDialog>

#include <memory>

class QCheckBox;
class QComboBox;
class QDateTimeEdit;
class QLineEdit;

namespace tick {

class Goal;

// 目标编辑对话框：新建 / 编辑 目标的名称、颜色、图标、起止日期、进度统计模式
class GoalDialog : public QDialog {
    Q_OBJECT
public:
    explicit GoalDialog(QWidget* parent = nullptr);

    /// 用现有目标初始化（编辑）；item 为 nullptr 时视为新建
    void setup(const std::shared_ptr<Goal>& item);

    /// 返回被编辑的目标（新建时返回新目标；仅在 accepted 后有效）
    std::shared_ptr<Goal> item() const { return item_; }

    void reapplyLanguage();

private slots:
    void onAccept();
    void onRejected();

private:
    void syncDateEnabled();

    QLineEdit* nameEdit_ = nullptr;
    QComboBox* colorCombo_ = nullptr;
    QLineEdit* iconEdit_ = nullptr;
    QCheckBox* startEnable_ = nullptr;
    QDateTimeEdit* startEdit_ = nullptr;
    QCheckBox* startPrecise_ = nullptr;
    QCheckBox* endEnable_ = nullptr;
    QDateTimeEdit* endEdit_ = nullptr;
    QCheckBox* endPrecise_ = nullptr;
    QComboBox* modeCombo_ = nullptr;

    std::shared_ptr<Goal> item_;
};

} // namespace tick