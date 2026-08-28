#pragma once

#include <QString>

#include <memory>
#include <string>
#include <vector>

#include "model/taskitem.h"

namespace tick {

// 任务仓储：树结构读写（goal 与 parent 互斥，自引用级联）
class TaskRepository {
public:
    /// 读取目标下的一级任务（递归重建整棵树，维护 parent 弱指针）
    std::vector<std::shared_ptr<TaskItem>> loadForGoal(const std::string& goalId);

    /// 保存整棵子树（按 id upsert；一级任务挂 goal，子任务按父链挂）
    void save(const std::shared_ptr<TaskItem>& task, const std::string& goalId);

    /// 删除任务（外键级联删除全部后代）
    void remove(const std::shared_ptr<TaskItem>& task);

private:
    std::vector<std::shared_ptr<TaskItem>> loadChildren(const QString& parentId,
                                                        const std::weak_ptr<TaskItem>& parent);
    std::vector<std::shared_ptr<TaskItem>> loadByParent(const QString& parentId, bool topLevel,
                                                        const QString& goalId,
                                                        const std::weak_ptr<TaskItem>& parent);
    void saveRecursive(const std::shared_ptr<TaskItem>& t, const QString& goalId,
                       const QString& parentId, bool isTopLevel);
};

} // namespace tick