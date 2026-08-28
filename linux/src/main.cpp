#include <QApplication>
#include <QIcon>
#include <QMessageBox>

#include "data/database.h"
#include "data/settingsrepository.h"
#include "ui/mainwindow.h"
#include "ui/theme.h"
#include "ui/translation.h"

int main(int argc, char** argv) {
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Tick"));
    app.setApplicationDisplayName(QStringLiteral("Tick"));
    app.setOrganizationName(QStringLiteral("Tick"));
    app.setApplicationVersion(QStringLiteral("1.0.0"));
    app.setWindowIcon(QIcon(QStringLiteral(":/icon/app_icon.png")));

    tick::Tr::loadFromSettings();

    tick::SettingsRepository settings;
    tick::applyAppPalette(settings.colorScheme());

    if (!tick::Database::instance().initialize()) {
        QMessageBox::critical(nullptr, QStringLiteral("Tick"),
                              QStringLiteral("无法打开数据库：%1")
                                  .arg(tick::Database::instance().errorString()));
        return 1;
    }

    tick::MainWindow window;
    window.show();
    return app.exec();
}