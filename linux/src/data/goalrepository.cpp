#include "data/goalrepository.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QVariant>

#include "data/database.h"

namespace tick {

namespace {

inline QString q(const std::string& s) {
    return QString::fromStdString(s);
}

inline std::optional<std::string> optString(const QString& s) {
    if (s.isEmpty()) return std::nullopt;
    return std::optional<std::string>(s.toStdString());
}

std::shared_ptr<Goal> parseGoalRow(QSqlQuery& query) {
    auto g = std::make_shared<Goal>();
    g->id = query.value(0).toString().toStdString();
    g->name = query.value(1).toString();
    g->colorHex = query.value(2).toString().toStdString();
    g->iconSystemName = optString(query.value(3).toString());
    g->startDate = dateTimeFromString(query.value(4).toString());
    g->endDate = dateTimeFromString(query.value(5).toString());
    g->startDatePreciseToHour = query.value(6).toBool();
    g->endDatePreciseToHour = query.value(7).toBool();
    g->createdAt = dateTimeFromString(query.value(8).toString()).value_or(QDateTime::currentDateTime());
    g->progressCountingMode = countingModeFromString(query.value(9).toString());
    return g;
}

} // namespace

std::vector<std::shared_ptr<Goal>> GoalRepository::all() {
    std::vector<std::shared_ptr<Goal>> out;
    QSqlQuery query(Database::instance().connection());
    query.exec(QStringLiteral(
        "SELECT id, name, color_hex, icon_system_name, start_date, end_date, "
        "start_date_precise_to_hour, end_date_precise_to_hour, created_at, progress_counting_mode "
        "FROM Goal ORDER BY created_at ASC"));
    while (query.next()) {
        out.push_back(parseGoalRow(query));
    }
    return out;
}

std::shared_ptr<Goal> GoalRepository::findById(const std::string& id) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "SELECT id, name, color_hex, icon_system_name, start_date, end_date, "
        "start_date_precise_to_hour, end_date_precise_to_hour, created_at, progress_counting_mode "
        "FROM Goal WHERE id = ?"));
    query.addBindValue(q(id));
    if (!query.exec() || !query.next()) {
        return nullptr;
    }
    return parseGoalRow(query);
}

bool GoalRepository::insert(const Goal& g) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "INSERT INTO Goal (id, name, color_hex, icon_system_name, start_date, end_date, "
        "start_date_precise_to_hour, end_date_precise_to_hour, created_at, progress_counting_mode) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"));
    query.addBindValue(q(g.id));
    query.addBindValue(g.name);
    query.addBindValue(q(g.colorHex));
    query.addBindValue(g.iconSystemName.has_value() ? q(*g.iconSystemName) : QVariant());
    query.addBindValue(dateTimeToString(g.startDate));
    query.addBindValue(dateTimeToString(g.endDate));
    query.addBindValue(g.startDatePreciseToHour ? 1 : 0);
    query.addBindValue(g.endDatePreciseToHour ? 1 : 0);
    query.addBindValue(g.createdAt.toString(Qt::ISODateWithMs));
    query.addBindValue(countingModeToString(g.progressCountingMode));
    return query.exec();
}

bool GoalRepository::update(const Goal& g) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral(
        "UPDATE Goal SET name = ?, color_hex = ?, icon_system_name = ?, start_date = ?, end_date = ?, "
        "start_date_precise_to_hour = ?, end_date_precise_to_hour = ?, progress_counting_mode = ? "
        "WHERE id = ?"));
    query.addBindValue(g.name);
    query.addBindValue(q(g.colorHex));
    query.addBindValue(g.iconSystemName.has_value() ? q(*g.iconSystemName) : QVariant());
    query.addBindValue(dateTimeToString(g.startDate));
    query.addBindValue(dateTimeToString(g.endDate));
    query.addBindValue(g.startDatePreciseToHour ? 1 : 0);
    query.addBindValue(g.endDatePreciseToHour ? 1 : 0);
    query.addBindValue(countingModeToString(g.progressCountingMode));
    query.addBindValue(q(g.id));
    return query.exec();
}

bool GoalRepository::remove(const std::string& id) {
    QSqlQuery query(Database::instance().connection());
    query.prepare(QStringLiteral("DELETE FROM Goal WHERE id = ?"));
    query.addBindValue(q(id));
    return query.exec();
}

} // namespace tick