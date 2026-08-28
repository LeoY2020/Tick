#include "ui/settingsdialog.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFile>
#include <QFileDialog>
#include <QFormLayout>
#include <QGroupBox>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QVBoxLayout>

#include "data/settingsrepository.h"
#include "services/jsonbackup.h"
#include "ui/theme.h"
#include "ui/translation.h"

namespace tick {

SettingsDialog::SettingsDialog(QWidget* parent) : QDialog(parent) {
    setModal(true);
    setMinimumWidth(420);

    SettingsRepository repo;

    schemeCombo_ = new QComboBox(this);
    schemeCombo_->addItem(TR("跟随系统", "System"), QStringLiteral("system"));
    schemeCombo_->addItem(TR("亮色", "Light"), QStringLiteral("light"));
    schemeCombo_->addItem(TR("暗色", "Dark"), QStringLiteral("dark"));
    const int sIdx = schemeCombo_->findData(repo.colorScheme());
    schemeCombo_->setCurrentIndex(sIdx < 0 ? 0 : sIdx);

    langCombo_ = new QComboBox(this);
    langCombo_->addItem(TR("简体中文", "Simplified Chinese"), QStringLiteral("zh"));
    langCombo_->addItem(TR("English", "English"), QStringLiteral("en"));
    const int lIdx = langCombo_->findData(repo.language());
    langCombo_->setCurrentIndex(lIdx < 0 ? 0 : lIdx);

    auto themeGroup = new QGroupBox(TR("外观", "Appearance"), this);
    auto themeForm = new QFormLayout(themeGroup);
    themeForm->addRow(TR("配色方案", "Color scheme"), schemeCombo_);
    themeForm->addRow(TR("语言", "Language"), langCombo_);

    providerCombo_ = new QComboBox(this);
    const std::vector<AIProvider> providers = {
        AIProvider::Qwen, AIProvider::DeepSeek, AIProvider::ChatGPT, AIProvider::Yuanbao,
        AIProvider::Claude, AIProvider::Gemini, AIProvider::GLM, AIProvider::Kimi,
        AIProvider::Ernie, AIProvider::Grok, AIProvider::StepFun, AIProvider::MiniMax,
        AIProvider::Custom,
    };
    for (AIProvider p : providers) {
        providerCombo_->addItem(aiProviderDisplayName(p), aiProviderToString(p));
    }
    const AIProvider curProvider = repo.aiProvider();
    {
        const int pIdx = providerCombo_->findData(aiProviderToString(curProvider));
        providerCombo_->setCurrentIndex(pIdx < 0 ? 0 : pIdx);
    }

    apiKeyEdit_ = new QLineEdit(this);
    apiKeyEdit_->setEchoMode(QLineEdit::Password);
    apiKeyEdit_->setPlaceholderText(TR("API Key", "API Key"));
    apiKeyEdit_->setText(repo.apiKey());

    baseUrlEdit_ = new QLineEdit(this);
    baseUrlEdit_->setText(repo.baseUrl());
    baseUrlEdit_->setPlaceholderText(QStringLiteral("https://api.deepseek.com/v1"));

    modelNameEdit_ = new QLineEdit(this);
    modelNameEdit_->setText(repo.modelName());
    modelNameEdit_->setPlaceholderText(QStringLiteral("deepseek-chat"));

    auto aiGroup = new QGroupBox(TR("AI 配置", "AI Configuration"), this);
    auto aiForm = new QFormLayout(aiGroup);
    aiForm->addRow(TR("供应商", "Provider"), providerCombo_);
    aiForm->addRow(TR("API Key", "API Key"), apiKeyEdit_);
    aiForm->addRow(TR("Base URL", "Base URL"), baseUrlEdit_);
    aiForm->addRow(TR("模型名", "Model name"), modelNameEdit_);
    aiGroup->setToolTip(TR("默认使用 OpenAI 兼容接口：DeepSeek（https://api.deepseek.com/v1 · deepseek-chat）",
                           "OpenAI-compatible by default: DeepSeek (https://api.deepseek.com/v1 · deepseek-chat)"));

    exportBtn_ = new QPushButton(TR("导出备份 (JSON)", "Export backup (JSON)"), this);
    importBtn_ = new QPushButton(TR("导入备份 (JSON)", "Import backup (JSON)"), this);
    auto backupGroup = new QGroupBox(TR("数据备份", "Data backup"), this);
    auto backupLayout = new QVBoxLayout(backupGroup);
    backupLayout->addWidget(exportBtn_);
    backupLayout->addWidget(importBtn_);

    auto buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);

    auto root = new QVBoxLayout(this);
    root->addWidget(themeGroup);
    root->addWidget(aiGroup);
    root->addWidget(backupGroup);
    root->addWidget(buttons);

    connect(exportBtn_, &QPushButton::clicked, this, &SettingsDialog::onExport);
    connect(importBtn_, &QPushButton::clicked, this, &SettingsDialog::onImport);
    connect(buttons, &QDialogButtonBox::accepted, this, &SettingsDialog::onAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &SettingsDialog::reject);

    reapplyLanguage();
}

void SettingsDialog::reapplyLanguage() {
    setWindowTitle(TR("设置", "Settings"));
}

void SettingsDialog::onAccept() {
    SettingsRepository repo;
    repo.setColorScheme(schemeCombo_->currentData().toString());
    repo.setLanguage(langCombo_->currentData().toString());
    repo.setAiProvider(aiProviderFromString(providerCombo_->currentData().toString()));
    repo.setApiKey(apiKeyEdit_->text().trimmed());
    repo.setBaseUrl(baseUrlEdit_->text().trimmed());
    repo.setModelName(modelNameEdit_->text().trimmed());

    // 立即应用主题与语言
    applyAppPalette(schemeCombo_->currentData().toString());
    Tr::setLang(langCombo_->currentData().toString());

    accept();
    emit settingsChanged();
}

void SettingsDialog::onExport() {
    const QString path = QFileDialog::getSaveFileName(
        this, TR("导出备份", "Export backup"), QStringLiteral("tick-backup.json"),
        QStringLiteral("JSON (*.json)"));
    if (path.isEmpty()) return;
    const QString json = JsonBackup::exportGoals();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        QMessageBox::warning(this, TR("导出失败", "Export failed"),
                             TR("无法写入文件", "Cannot write file"));
        return;
    }
    f.write(json.toUtf8());
    f.close();
    QMessageBox::information(this, TR("导出", "Export"), TR("备份已导出", "Backup exported"));
}

void SettingsDialog::onImport() {
    QMessageBox::StandardButton ret = QMessageBox::question(
        this, TR("导入备份", "Import backup"),
        TR("导入将替换当前全部数据，是否继续？", "Import will replace all current data. Continue?"));
    if (ret != QMessageBox::Yes) return;

    const QString path = QFileDialog::getOpenFileName(
        this, TR("选择备份文件", "Select backup file"), QString(), QStringLiteral("JSON (*.json)"));
    if (path.isEmpty()) return;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        QMessageBox::warning(this, TR("导入失败", "Import failed"), TR("无法读取文件", "Cannot read file"));
        return;
    }
    const QString json = QString::fromUtf8(f.readAll());
    f.close();
    QString error;
    if (!JsonBackup::importGoals(json, error)) {
        QMessageBox::warning(this, TR("导入失败", "Import failed"), error);
        return;
    }
    QMessageBox::information(this, TR("导入", "Import"), TR("备份已导入", "Backup imported"));
    emit settingsChanged();
}

} // namespace tick