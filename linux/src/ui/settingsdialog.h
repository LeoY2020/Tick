#pragma once

#include <QDialog>

class QComboBox;
class QLineEdit;
class QPushButton;

namespace tick {

// 设置对话框：配色方案、语言、AI 配置（OpenAI 兼容 API）、JSON 备份导出/导入
class SettingsDialog : public QDialog {
    Q_OBJECT
public:
    explicit SettingsDialog(QWidget* parent = nullptr);

    void reapplyLanguage();

signals:
    /// 设置变更（配色 / 语言 / 数据导入）后发射，供主界面刷新
    void settingsChanged();

private slots:
    void onAccept();
    void onExport();
    void onImport();

private:
    QComboBox* schemeCombo_ = nullptr;
    QComboBox* langCombo_ = nullptr;
    QComboBox* providerCombo_ = nullptr;
    QLineEdit* apiKeyEdit_ = nullptr;
    QLineEdit* baseUrlEdit_ = nullptr;
    QLineEdit* modelNameEdit_ = nullptr;
    QPushButton* exportBtn_ = nullptr;
    QPushButton* importBtn_ = nullptr;
};

} // namespace tick