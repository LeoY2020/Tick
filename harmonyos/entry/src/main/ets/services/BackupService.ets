import fs from '@ohos.file.fs';
import fileManager from '@ohos.file.fileManager';
import fileUri from '@ohos.file.fileUri';
import common from '@ohos.app.ability.common';
import { Database } from '../data/Database';
import { GoalRepository, TaskRepository } from '../data/Repositories';
import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';

/** 备份文件 JSON 结构（goals + 扁平 tasks） */
interface BackupGoalJSON {
  id: string;
  name: string;
  colorHex: string;
  iconSystemName?: string;
  startDate?: number;
  endDate?: number;
  startDatePreciseToHour: boolean;
  endDatePreciseToHour: boolean;
  createdAt: number;
  progressCountingMode: string;
}

interface BackupTaskJSON {
  id: string;
  name: string;
  colorHex?: string;
  iconSystemName?: string;
  type: string;
  status: string;
  totalAmount: number;
  currentAmount: number;
  startDate?: number;
  endDate?: number;
  reminderDate?: number;
  repeatRule?: string;
  customWeekdaysRaw?: string;
  createdAt: number;
  sortOrder: number;
  parentTaskId?: string;
  goalId?: string;
}

interface BackupEnvelope {
  app: string;
  version: number;
  exportedAt: number;
  goals: BackupGoalJSON[];
  tasks: BackupTaskJSON[];
}

/**
 * JSON 导出 / 导入备份。
 * 导出：将全部目标与任务序列化为 JSON 写入 系统 Download 目录（失败时回落应用沙箱）。
 * 导入：解析备份文件并 upsert 目标与任务。
 */
export class BackupService {

  /** 导出全部数据到 Download，返回写入的文件路径 */
  static async export(context: common.UIAbilityContext): Promise<string> {
    const envelope = await BackupService.collect();
    const json = JSON.stringify(envelope);
    const timestamp = Date.now();
    const fileName = `tick_backup_${timestamp}.json`;

    // 优先写入系统 Download 目录
    let targetPath = '';
    try {
      const dirs = await fileManager.getDownloadDirs(context);
      if (dirs.length > 0) {
        const dirUri = dirs[0].uri;
        const dirPath = new fileUri.FileUri(dirUri).path;
        targetPath = `${dirPath}/${fileName}`;
      }
    } catch (e) {
      // 获取 Download 目录失败：回落应用沙箱
    }
    if (targetPath.length === 0) {
      targetPath = `${context.filesDir}/${fileName}`;
    }

    const f = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(f.fd, json);
    } finally {
      fs.closeSync(f.fd);
    }
    return targetPath;
  }

  /** 导入备份文件（uri 或路径），返回导入的目标数 */
  static async import(context: common.UIAbilityContext, uriOrPath: string): Promise<number> {
    const jsonText = await BackupService.readText(uriOrPath);
    let envelope: BackupEnvelope;
    try {
      envelope = JSON.parse(jsonText) as BackupEnvelope;
    } catch (e) {
      throw new Error('备份文件内容不是有效的 JSON');
    }
    if (envelope === undefined || envelope === null || envelope.goals === undefined) {
      throw new Error('备份文件缺少数据');
    }

    let goalCount = 0;
    for (const g of envelope.goals) {
      if (g.id === undefined || g.name === undefined) {
        continue;
      }
      const goal = new Goal();
      goal.id = g.id;
      goal.name = g.name;
      goal.colorHex = g.colorHex === undefined ? 'auto' : g.colorHex;
      goal.iconSystemName = g.iconSystemName;
      goal.startDate = g.startDate;
      goal.endDate = g.endDate;
      goal.startDatePreciseToHour = g.startDatePreciseToHour === true;
      goal.endDatePreciseToHour = g.endDatePreciseToHour === true;
      goal.createdAt = g.createdAt === undefined ? Date.now() : g.createdAt;
      const mode = g.progressCountingMode;
      goal.progressCountingMode = (mode === 'leafTasks') ? 'leafTasks' : 'allTasks';
      await GoalRepository.save(goal);
      goalCount += 1;
    }

    let taskCount = 0;
    for (const t of envelope.tasks) {
      if (t.id === undefined || t.name === undefined) {
        continue;
      }
      const task = new TaskItem();
      task.id = t.id;
      task.name = t.name;
      task.colorHex = t.colorHex;
      task.iconSystemName = t.iconSystemName;
      task.type = t.type === 'progress' ? 'progress' : 'single';
      task.status = BackupService.normalizeStatus(t.status);
      task.totalAmount = t.totalAmount === undefined ? 0 : t.totalAmount;
      task.currentAmount = t.currentAmount === undefined ? 0 : t.currentAmount;
      task.startDate = t.startDate;
      task.endDate = t.endDate;
      task.reminderDate = t.reminderDate;
      task.repeatRule = t.repeatRule === undefined ? undefined : t.repeatRule;
      task.customWeekdaysRaw = t.customWeekdaysRaw;
      task.createdAt = t.createdAt === undefined ? Date.now() : t.createdAt;
      task.sortOrder = t.sortOrder === undefined ? 0 : t.sortOrder;
      task.parentTaskId = t.parentTaskId;
      task.goalId = t.goalId;
      await TaskRepository.save(task);
      taskCount += 1;
    }
    return goalCount;
  }

  /** 从数据库收集全部目标与扁平任务 */
  private static async collect(): Promise<BackupEnvelope> {
    const store = Database.getStore();
    const goals = await GoalRepository.list();
    const goalRows: BackupGoalJSON[] = [];
    for (const g of goals) {
      const row: BackupGoalJSON = {
        id: g.id,
        name: g.name,
        colorHex: g.colorHex,
        iconSystemName: g.iconSystemName,
        startDate: g.startDate,
        endDate: g.endDate,
        startDatePreciseToHour: g.startDatePreciseToHour,
        endDatePreciseToHour: g.endDatePreciseToHour,
        createdAt: g.createdAt,
        progressCountingMode: g.progressCountingMode
      };
      goalRows.push(row);
    }

    const taskRows: BackupTaskJSON[] = [];
    const rs = await store.querySql('SELECT * FROM task ORDER BY sortOrder ASC, createdAt ASC');
    try {
      while (rs.goToNextRow()) {
        const parentId = rs.isColumnNull(rs.getColumnIndex('parentTaskId')) ? undefined : rs.getString(rs.getColumnIndex('parentTaskId'));
        const goalId = rs.isColumnNull(rs.getColumnIndex('goalId')) ? undefined : rs.getString(rs.getColumnIndex('goalId'));
        const row: BackupTaskJSON = {
          id: rs.getString(rs.getColumnIndex('id')),
          name: rs.getString(rs.getColumnIndex('name')),
          colorHex: rs.isColumnNull(rs.getColumnIndex('colorHex')) ? undefined : rs.getString(rs.getColumnIndex('colorHex')),
          iconSystemName: rs.isColumnNull(rs.getColumnIndex('iconSystemName')) ? undefined : rs.getString(rs.getColumnIndex('iconSystemName')),
          type: rs.getString(rs.getColumnIndex('type')),
          status: rs.getString(rs.getColumnIndex('status')),
          totalAmount: rs.getDouble(rs.getColumnIndex('totalAmount')),
          currentAmount: rs.getDouble(rs.getColumnIndex('currentAmount')),
          startDate: rs.isColumnNull(rs.getColumnIndex('startDate')) ? undefined : rs.getLong(rs.getColumnIndex('startDate')),
          endDate: rs.isColumnNull(rs.getColumnIndex('endDate')) ? undefined : rs.getLong(rs.getColumnIndex('endDate')),
          reminderDate: rs.isColumnNull(rs.getColumnIndex('reminderDate')) ? undefined : rs.getLong(rs.getColumnIndex('reminderDate')),
          repeatRule: rs.isColumnNull(rs.getColumnIndex('repeatRule')) ? undefined : rs.getString(rs.getColumnIndex('repeatRule')),
          customWeekdaysRaw: rs.isColumnNull(rs.getColumnIndex('customWeekdaysRaw')) ? undefined : rs.getString(rs.getColumnIndex('customWeekdaysRaw')),
          createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
          sortOrder: rs.getLong(rs.getColumnIndex('sortOrder')),
          parentTaskId: parentId,
          goalId: goalId
        };
        taskRows.push(row);
      }
    } finally {
      rs.close();
    }

    return {
      app: 'tick',
      version: 1,
      exportedAt: Date.now(),
      goals: goalRows,
      tasks: taskRows
    };
  }

  private static normalizeStatus(raw: string | undefined): 'notDone' | 'halfDone' | 'done' | 'deleted' {
    if (raw === 'halfDone' || raw === 'done' || raw === 'deleted') {
      return raw;
    }
    return 'notDone';
  }

  private static async readText(uriOrPath: string): Promise<string> {
    let path = uriOrPath;
    // 文件选择器返回的 file:// uri → 真实路径；datashare:// 直接以 uri 打开（已授权读）
    if (path.startsWith('file://')) {
      path = new fileUri.FileUri(path).path;
    }
    let fd = -1;
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      fd = file.fd;
      return await fs.readText(fd);
    } finally {
      if (fd >= 0) {
        fs.closeSync(fd);
      }
    }
  }
}