#include "ui/mainwindow.h"

#include <QAction>
#include <QApplication>
#include <QBrush>
#include <QCloseEvent>
#include <QHeaderView>
#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QListWidget>
#include <QMenu>
#include <QMessageBox>
#include <QPalette>
#include <QProgressBar>
#include <QPushButton>
#include <QScrollArea>
#include <QSplitter>
#include <QStatusBar>
#include <QTreeWidget>
#include <QVBoxLayout>

#include <algorithm>
#include <cmath>
#include <functional>

#include "data/goalrepository.h"
#include "data/settingsrepository.h"
#include "data/taskrepository.h"
#include "domain/progressengine.h"
#include "model/enums.h"
#include "model/goal.h"
#include "model/taskitem.h"
#include "services/aiservice.h"
#include "services/notificationservice.h"
#include "ui/aichatdialog.h"
#include "ui/goaldialog.h"
#include "ui/settingsdialog.h"
#include "ui/taskdialog.h"
#include "ui/theme.h"
#include "ui/translation.h"

namespace tick {

MainWindow::MainWindow(QWidget* parent) : QMainWindow(parent) {
    setWindowTitle(TR("Tick — 待办", "Tick — Todo"));
    resize(980, 640);

    notifications_ = new NotificationService(this);
    notifications_->setEnabled(true);

    // ---- 左：Goal 列表侧栏 ----
    goalList_ = new QListWidget(this);
    goalList_->setObjectName(QStringLiteral("goalSidebar"));
    addGoalBtn_ = new QPushButton(TR("新增", "Add"), this);
    editGoalBtn_ = new QPushButton(TR("编辑", "Edit"), this);
    removeGoalBtn_ = new QPushButton(TR("删除", "Remove"), this);
    auto goalBtnRow = new QHBoxLayout;
    goalBtnRow->addWidget(addGoalBtn_);
    goalBtnRow->addWidget(editGoalBtn_);
    goalBtnRow->addWidget(removeGoalBtn_);

    auto sidebar = new QWidget(this);
    auto sidebarLayout = new QVBoxLayout(sidebar);
    sidebarLayout->setContentsMargins(4, 4, 4, 4);
    auto sidebarTitle = new QLabel(TR("目标", "Goals"), sidebar);
    sidebarTitle->setStyleSheet(QStringLiteral("font-weight:bold;"));
    sidebarLayout->addWidget(sidebarTitle);
    sidebarLayout->addWidget(goalList_, 1);
    sidebarLayout->addLayout(goalBtnRow);
    sidebar->setMinimumWidth(200);

    // ---- 右：主视图 ----
    auto mainView = new QWidget(this);
    auto mainLayout = new QVBoxLayout(mainView);
    mainLayout->setContentsMargins(8, 8, 8, 8);
    mainLayout->setSpacing(6);

    goalTitleLabel_ = new QLabel(TR("未选择目标", "No goal selected"), mainView);
    goalTitleLabel_->setStyleSheet(QStringLiteral("font-size:20px;font-weight:bold;"));
    modeLabel_ = new QLabel(mainView);

    progressBar_ = new QProgressBar(mainView);
    progressBar_->setRange(0, 100);
    progressBar_->setValue(0);
    progressBar_->setTextVisible(true);

    progressTextLabel_ = new QLabel(mainView);
    countdownLabel_ = new QLabel(mainView);
    countdownLabel_->setStyleSheet(QStringLiteral("color:#888;"));

    taskTree_ = new QTreeWidget(mainView);
    taskTree_->setColumnCount(3);
    taskTree_->setHeaderLabels({TR("名称", "Name"), TR("详情", "Detail"), TR("进度", "Progress")});
    taskTree_->setContextMenuPolicy(Qt::CustomContextMenu);
    taskTree_->header()->setSectionResizeMode(0, QHeaderView::Stretch);
    taskTree_->header()->setSectionResizeMode(1, QHeaderView::ResizeToContents);
    taskTree_->header()->setSectionResizeMode(2, QHeaderView::ResizeToContents);

    addTaskBtn_ = new QPushButton(TR("添加任务", "Add task"), mainView);
    aiBtn_ = new QPushButton(TR("AI 助手", "AI Assistant"), mainView);
    settingsBtn_ = new QPushButton(TR("设置", "Settings"), mainView);
    auto bottomRow = new QHBoxLayout;
    bottomRow->addWidget(addTaskBtn_, 1);
    bottomRow->addWidget(aiBtn_);
    bottomRow->addWidget(settingsBtn_);

    mainLayout->addWidget(goalTitleLabel_);
    mainLayout->addWidget(modeLabel_);
    mainLayout->addWidget(progressBar_);
    mainLayout->addWidget(progressTextLabel_);
    mainLayout->addWidget(countdownLabel_);
    mainLayout->addWidget(taskTree_, 1);
    mainLayout->addLayout(bottomRow);

    splitter_ = new QSplitter(Qt::Horizontal, this);
    splitter_->addWidget(sidebar);
    splitter_->addWidget(mainView);
    splitter_->setStretchFactor(0, 0);
    splitter_->setStretchFactor(1, 1);
    setCentralWidget(splitter_);

    connect(goalList_, &QListWidget::currentItemChanged,
            this, &MainWindow::onGoalSelectionChanged);
    connect(addGoalBtn_, &QPushButton::clicked, this, &MainWindow::addGoal);
    connect(editGoalBtn_, &QPushButton::clicked, this, &MainWindow::editGoal);
    connect(removeGoalBtn_, &QPushButton::clicked, this, &MainWindow::removeGoal);
    connect(addTaskBtn_, &QPushButton::clicked, this, &MainWindow::addTopLevelTask);
    connect(taskTree_, &QWidget::customContextMenuRequested, this, &MainWindow::onTreeContextMenu);
    connect(settingsBtn_, &QPushButton::clicked, this, &MainWindow::openSettings);
    connect(aiBtn_, &QPushButton::clicked, this, &MainWindow::openAIChat);

    chatDialog_ = new AIChatDialog(this);
    connect(chatDialog_, &AIChatDialog::generatedTasksReady, this, &MainWindow::onGeneratedTasks);

    reapplyLanguage();
    applyTheme();
    reloadGoals();
}

void MainWindow::applyTheme() {
    SettingsRepository repo;
    applyAppPalette(repo.colorScheme());
}

void MainWindow::reapplyLanguage() {
    setWindowTitle(TR("Tick — 待办", "Tick — Todo"));
    addGoalBtn_->setText(TR("新增", "Add"));
    editGoalBtn_->setText(TR("编辑", "Edit"));
    removeGoalBtn_->setText(TR("删除", "Remove"));
    addTaskBtn_->setText(TR("添加任务", "Add task"));
    aiBtn_->setText(TR("AI 助手", "AI Assistant"));
    settingsBtn_->setText(TR("设置", "Settings"));
    taskTree_->setHeaderLabels({TR("名称", "Name"), TR("详情", "Detail"), TR("进度", "Progress")});
    if (chatDialog_) chatDialog_->reapplyLanguage();
}

void MainWindow::reloadGoals() {
    const QString prevId = goalList_->currentItem()
                               ? goalList_->currentItem()->data(Qt::UserRole).toString()
                               : QString();
    goalList_->clear();
    GoalRepository repo;
    const auto goals = repo.all();
    for (const auto& g : goals) {
        auto* item = new QListWidgetItem(g->name, goalList_);
        item->setData(Qt::UserRole, QString::fromStdString(g->id));
        // 颜色标识
        const bool dark = qApp->palette().color(QPalette::Window).lightnessF() < 0.5;
        item->setForeground(QBrush(resolveColor(QString::fromStdString(g->colorHex), dark)));
    }
    // 恢复之前选中的目标
    if (!prevId.isEmpty()) {
        for (int i = 0; i < goalList_->count(); ++i) {
            if (goalList_->item(i)->data(Qt::UserRole).toString() == prevId) {
                goalList_->setCurrentRow(i);
                break;
            }
        }
    }
    if (!goalList_->currentItem() && goalList_->count() > 0) {
        goalList_->setCurrentRow(0);
    }
    if (goalList_->count() == 0) {
        currentGoal_.reset();
        currentTasks_.clear();
        taskById_.clear();
        taskTree_->clear();
        goalTitleLabel_->setText(TR("未选择目标", "No goal selected"));
        modeLabel_->clear();
        progressBar_->setValue(0);
        progressTextLabel_->clear();
        countdownLabel_->clear();
    }
    rescheduleNotifications();
}

void MainWindow::selectGoal(const std::string& goalId) {
    const QString id = QString::fromStdString(goalId);
    for (int i = 0; i < goalList_->count(); ++i) {
        if (goalList_->item(i)->data(Qt::UserRole).toString() == id) {
            goalList_->setCurrentRow(i);
            break;
        }
    }
}

void MainWindow::onGoalSelectionChanged() {
    QListWidgetItem* current = goalList_->currentItem();
    if (!current) {
        currentGoal_.reset();
        currentTasks_.clear();
        taskById_.clear();
        taskTree_->clear();
        return;
    }
    const std::string id = current->data(Qt::UserRole).toString().toStdString();
    GoalRepository goalRepo;
    currentGoal_ = goalRepo.findById(id);
    if (!currentGoal_) {
        currentTasks_.clear();
        taskById_.clear();
        taskTree_->clear();
        return;
    }
    loadTasks();
}

void MainWindow::loadTasks() {
    if (!currentGoal_) return;
    TaskRepository taskRepo;
    currentTasks_ = taskRepo.loadForGoal(currentGoal_->id);
    // 重建 id -> 任务 映射
    taskById_.clear();
    std::function<void(const std::shared_ptr<TaskItem>&)> indexRec =
        [&](const std::shared_ptr<TaskItem>& t) {
            taskById_[t->id] = t;
            for (const auto& c : t->subtasks) indexRec(c);
        };
    for (const auto& t : currentTasks_) indexRec(t);
    taskTree_->clear();
    for (const auto& t : currentTasks_) {
        buildTree(t, nullptr);
    }
    refreshGoalHeader();
    rescheduleNotifications();
}

void MainWindow::buildTree(const std::shared_ptr<TaskItem>& task, QTreeWidgetItem* parent) {
    auto* it = new QTreeWidgetItem;
    if (parent) {
        parent->addChild(it);
    } else {
        taskTree_->addTopLevelItem(it);
    }
    it->setData(0, Qt::UserRole, QString::fromStdString(task->id));
    it->setText(0, task->name);

    // 详情列
    QString detail;
    if (task->type == TaskType::Progress) {
        const auto progress = ProgressEngine::effectiveProgress(*task);
        detail = QStringLiteral("%1/%2").arg(progress.first).arg(progress.second);
    } else {
        detail = taskStatusDisplayName(ProgressEngine::effectiveStatus(*task));
    }
    it->setText(1, detail);

    // 颜色（有效颜色回退链）
    const bool dark = qApp->palette().color(QPalette::Window).lightnessF() < 0.5;
    const std::string hex = ProgressEngine::effectiveColor(*task, currentGoal_.get());
    it->setForeground(0, QBrush(resolveColor(QString::fromStdString(hex), dark)));

    // 进度条（有效比率）
    const auto progress = ProgressEngine::effectiveProgress(*task);
    int percent = 0;
    if (progress.second > 0.0) {
        percent = static_cast<int>(std::lround(progress.first / progress.second * 100.0));
    }
    percent = std::clamp(percent, 0, 100);
    it->setProgressBar(2, percent);
    it->setText(2, QStringLiteral("%1%").arg(percent));

    for (const auto& c : task->subtasks) {
        buildTree(c, it);
    }
}

void MainWindow::refreshGoalHeader() {
    if (!currentGoal_) return;
    goalTitleLabel_->setText(currentGoal_->name);
    modeLabel_->setText(TR("统计模式：%1", "Counting: %1")
                            .arg(countingModeDisplayName(currentGoal_->progressCountingMode)));
    const GoalProgress gp = ProgressEngine::goalProgress(*currentGoal_);
    const int percent = gp.totalItems == 0
                            ? 0
                            : static_cast<int>(std::lround(gp.fraction() * 100.0));
    progressBar_->setValue(std::clamp(percent, 0, 100));
    progressTextLabel_->setText(TR("已完成 %1 / %2 项", "%1 / %2 completed")
                                    .arg(gp.completedWeight)
                                    .arg(gp.totalItems));
    countdownLabel_->setText(countdownText());
}

QString MainWindow::countdownText() const {
    if (!currentGoal_ || !currentGoal_->endDate.has_value()) return QString();
    const QDateTime end = *currentGoal_->endDate;
    const QDateTime now = QDateTime::currentDateTime();
    if (!end.isValid() || end <= now) return QString();

    // 简化倒计时：日 / 时 / 分
    const qint64 secs = now.secsTo(end);
    const int days = static_cast<int>(secs / 86400);
    const int hours = static_cast<int>((secs % 86400) / 3600);
    if (days > 0) {
        return TR("截止倒计时：%1 天 %2 小时", "Due in %1d %2h").arg(days).arg(hours);
    }
    const int minutes = static_cast<int>((secs % 3600) / 60);
    if (hours > 0) {
        return TR("截止倒计时：%1 小时 %2 分", "Due in %1h %2m").arg(hours).arg(minutes);
    }
    return TR("截止倒计时：%1 分", "Due in %1m").arg(minutes);
}

void MainWindow::saveTask(const std::shared_ptr<TaskItem>& task) {
    if (!currentGoal_) return;
    TaskRepository repo;
    repo.save(task, currentGoal_->id);
}

void MainWindow::persistAndReload() {
    if (!currentGoal_) return;
    // 保存全部一级任务（递归 upsert 子树）
    TaskRepository repo;
    for (const auto& t : currentTasks_) {
        repo.save(t, currentGoal_->id);
    }
    loadTasks();
}

void MainWindow::addGoal() {
    GoalDialog dlg(this);
    dlg.exec();
    if (dlg.result() != QDialog::Accepted) return;
    std::shared_ptr<Goal> g = dlg.item();
    GoalRepository repo;
    if (g->createdAt < QDateTime::fromMSecsSinceEpoch(1)) {
        g->createdAt = QDateTime::currentDateTime(); // 兜底：新目标记录创建时间
    }
    if (g->id.empty()) g->id = makeId();
    if (!repo.insert(*g)) {
        QMessageBox::warning(this, TR("出错", "Error"), TR("保存目标失败", "Failed to save goal"));
        return;
    }
    reloadGoals();
    selectGoal(g->id);
    rescheduleNotifications();
}

void MainWindow::editGoal() {
    QListWidgetItem* current = goalList_->currentItem();
    if (!current) return;
    const std::string id = current->data(Qt::UserRole).toString().toStdString();
    GoalRepository repo;
    auto g = repo.findById(id);
    if (!g) return;
    GoalDialog dlg(this);
    dlg.setup(g);
    dlg.exec();
    if (dlg.result() != QDialog::Accepted) return;
    if (!repo.update(*g)) {
        QMessageBox::warning(this, TR("出错", "Error"), TR("保存目标失败", "Failed to save goal"));
        return;
    }
    reloadGoals();
    selectGoal(id);
    rescheduleNotifications();
}

void MainWindow::removeGoal() {
    QListWidgetItem* current = goalList_->currentItem();
    if (!current) return;
    const std::string id = current->data(Qt::UserRole).toString().toStdString();
    const QMessageBox::StandardButton ret = QMessageBox::question(
        this, TR("删除目标", "Delete goal"),
        TR("删除该目标及其全部任务？", "Delete this goal and all its tasks?"));
    if (ret != QMessageBox::Yes) return;
    GoalRepository repo;
    repo.remove(id);
    reloadGoals();
    rescheduleNotifications();
}

void MainWindow::addTopLevelTask() {
    if (!currentGoal_) return;
    auto task = std::make_shared<TaskItem>();
    task->goalId = currentGoal_->id;
    TaskDialog dlg(this);
    dlg.setup(task);
    dlg.exec();
    if (dlg.result() != QDialog::Accepted) return;
    currentTasks_.push_back(task);
    persistAndReload();
    rescheduleNotifications();
}

void MainWindow::onTreeContextMenu(const QPoint& pos) {
    if (!currentGoal_) return;
    QTreeWidgetItem* item = taskTree_->itemAt(pos);
    if (!item) return;
    const std::string id = item->data(0, Qt::UserRole).toString().toStdString();
    const auto task = taskById_.find(id);
    if (task == taskById_.end()) return;
    const std::shared_ptr<TaskItem>& t = task->second;

    QMenu menu(this);
    const bool single = (t->type == TaskType::Single);
    const bool userEditable = single && !t->hasSubtasks(); // 有子任务只读，由子任务折算

    QAction* addSub = menu.addAction(TR("添加子任务", "Add subtask"));
    QAction* edit = menu.addAction(TR("编辑", "Edit"));
    QAction* del = menu.addAction(TR("删除（级联）", "Delete (cascade)"));
    QAction* toggleStatus = nullptr;
    QAction* toggleDeleted = nullptr;
    if (userEditable) {
        toggleStatus = menu.addAction(TR("切换状态", "Toggle status"));
        toggleDeleted = menu.addAction(TR("标记删除 / 取消", "Mark deleted / normal"));
    }

    QAction* chosen = menu.exec(taskTree_->viewport()->mapToGlobal(pos));
    if (!chosen) return;

    if (chosen == addSub) {
        auto child = std::make_shared<TaskItem>();
        child->parentTaskId = t->id;
        child->parent = t;
        TaskDialog dlg(this);
        dlg.setup(child);
        dlg.exec();
        if (dlg.result() != QDialog::Accepted) return;
        t->subtasks.push_back(child);
        persistAndReload();
        rescheduleNotifications();
    } else if (chosen == edit) {
        TaskDialog dlg(this);
        dlg.setup(t);
        dlg.exec();
        if (dlg.result() != QDialog::Accepted) return;
        persistAndReload();
        rescheduleNotifications();
    } else if (chosen == del) {
        const QMessageBox::StandardButton ret = QMessageBox::question(
            this, TR("删除任务", "Delete task"),
            TR("删除该任务及其全部子任务？", "Delete this task and all its subtasks?"));
        if (ret != QMessageBox::Yes) return;
        // 从内存父节点移除
        auto parent = t->parent.lock();
        TaskRepository repo;
        if (parent) {
            auto& subs = parent->subtasks;
            subs.erase(std::remove_if(subs.begin(), subs.end(),
                                      [&](const std::shared_ptr<TaskItem>& c) { return c->id == t->id; }),
                       subs.end());
        } else {
            currentTasks_.erase(std::remove_if(currentTasks_.begin(), currentTasks_.end(),
                                               [&](const std::shared_ptr<TaskItem>& c) { return c->id == t->id; }),
                                currentTasks_.end());
        }
        repo.remove(t);
        persistAndReload();
        rescheduleNotifications();
    } else if (toggleStatus && chosen == toggleStatus) {
        TaskStatus s = t->status;
        if (s == TaskStatus::NotDone) t->status = TaskStatus::HalfDone;
        else if (s == TaskStatus::HalfDone) t->status = TaskStatus::Done;
        else if (s == TaskStatus::Done) t->status = TaskStatus::NotDone;
        else t->status = TaskStatus::NotDone;
        persistAndReload();
        rescheduleNotifications();
    } else if (toggleDeleted && chosen == toggleDeleted) {
        t->status = (t->status == TaskStatus::Deleted) ? TaskStatus::NotDone : TaskStatus::Deleted;
        persistAndReload();
        rescheduleNotifications();
    }
}

void MainWindow::openSettings() {
    SettingsDialog dlg(this);
    connect(&dlg, &SettingsDialog::settingsChanged, this, &MainWindow::rebuildAllFromSettings);
    dlg.exec();
}

void MainWindow::rebuildAllFromSettings() {
    reapplyLanguage();
    applyTheme();
    reloadGoals();
    // 立即刷新当前目标（颜色随主题变化）
    if (goalList_->currentItem()) loadTasks();
}

void MainWindow::openAIChat() {
    if (!currentGoal_) {
        QMessageBox::information(this, TR("提示", "Notice"),
                                 TR("请先选择或新建一个目标", "Please select or create a goal first"));
        return;
    }
    chatDialog_->show();
    chatDialog_->raise();
    chatDialog_->activateWindow();
}

std::shared_ptr<TaskItem> MainWindow::generatedToTask(const std::shared_ptr<GeneratedTask>& g) {
    auto t = std::make_shared<TaskItem>();
    t->name = g->name;
    for (const auto& c : g->children) {
        auto child = generatedToTask(c);
        child->parent = t;
        t->subtasks.push_back(child);
    }
    return t;
}

void MainWindow::onGeneratedTasks(const std::vector<std::shared_ptr<GeneratedTask>>& tasks) {
    if (!currentGoal_) return;
    for (const auto& g : tasks) {
        auto t = generatedToTask(g);
        t->goalId = currentGoal_->id;
        currentTasks_.push_back(t);
    }
    persistAndReload();
    rescheduleNotifications();
    QMessageBox::information(this, TR("AI 助手", "AI Assistant"),
                             TR("已生成 %1 个一级任务，写入目标「%2」", "Generated %1 tasks into \"%2\"")
                                 .arg(tasks.size())
                                 .arg(currentGoal_->name));
}

void MainWindow::rescheduleNotifications() {
    GoalRepository goalRepo;
    TaskRepository taskRepo;
    std::vector<std::shared_ptr<Goal>> goals;
    for (const auto& g : goalRepo.all()) {
        g->tasks = taskRepo.loadForGoal(g->id);
        goals.push_back(g);
    }
    notifications_->reschedule(goals);
}

void MainWindow::closeEvent(QCloseEvent* event) {
    if (chatDialog_ && chatDialog_->isVisible()) chatDialog_->close();
    event->accept();
}

} // namespace tick