#pragma once

#include <memory>
#include <string>
#include <vector>

#include "model/goal.h"

namespace tick {

// 目标仓储：CRUD（删除时由外键级联删除其下全部任务）
class GoalRepository {
public:
    std::vector<std::shared_ptr<Goal>> all();
    std::shared_ptr<Goal> findById(const std::string& id);
    bool insert(const Goal& goal);
    bool update(const Goal& goal);
    bool remove(const std::string& id);
};

} // namespace tick