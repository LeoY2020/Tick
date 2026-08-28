#pragma once

#include <QMainWindow>

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

class QLabel;
class QListWidget;
class QProgressBar;
class QPushButton;
class QSplitter;
class QTreeWidget;
class QTreeWidgetItem;

namespace tick {

class Goal;
class TaskItem;
class GeneratedTask;
class AIChatDialog;
class NotificationService;

// 主窗口：QSplitter 左（Goal 列表侧栏 add/edit/remove）右（目标标题 + 总进度 + 倒计时 + 任务树 + 底部添加）
class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget* parent = nullptr);

    void reloadGoals();
    void selectGoal(const std::string& goalId);

private slots:
    void onGoalSelectionChanged();
    void addGoal();
    void editGoal();
    void removeGoal();
    void addTopLevelTask();
    void onTreeContextMenu(const QPoint& pos);
    void openSettings();
    void openAIChat();
    void onGeneratedTasks(const std::vector<std::shared_ptr<GeneratedTask>>& tasks);

private:
    void loadTasks();
    void buildTree(const std::shared_ptr<TaskItem>& task, QTreeWidgetItem* parent);
    void refreshGoalHeader();
    QString countdownText() const;
    void persistAndReload();
    void rescheduleNotifications();
    void rebuildAllFromSettings();
    void applyTheme();
    void reapplyLanguage();
    std::shared_ptr<TaskItem> generatedToTask(const std::shared_ptr<GeneratedTask>& g);

    QSplitter* splitter_ = nullptr;
    QListWidget* goalList_ = nullptr;
    QPushButton* addGoalBtn_ = nullptr;
    QPushButton* editGoalBtn_ = nullptr;
    QPushButton* removeGoalBtn_ = nullptr;

    QLabel* goalTitleLabel_ = nullptr;
    QLabel* modeLabel_ = nullptr;
    QProgressBar* progressBar_ = nullptr;
    QLabel* progressTextLabel_ = nullptr;
    QLabel* countdownLabel_ = nullptr;
    QTreeWidget* taskTree_ = nullptr;
    QPushButton* addTaskBtn_ = nullptr;
    QPushButton* aiBtn_ = nullptr;
    QPushButton* settingsBtn_ = nullptr;

    AIChatDialog* chatDialog_ = nullptr;
    NotificationService* notifications_ = nullptr;

    std::shared_ptr<Goal> currentGoal_;
    std::vector<std::shared_ptr<TaskItem>> currentTasks_;
    std::unordered_map<std::string, std::shared_ptr<TaskItem>> taskById_;
};

} // namespace tick