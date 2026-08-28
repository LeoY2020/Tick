import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';

/** 数据库配置：stage 模型 RDB（relationalStore） */
const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'tick.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_GOAL = 'CREATE TABLE IF NOT EXISTS goal (' +
  'id TEXT PRIMARY KEY, ' +
  'name TEXT NOT NULL DEFAULT \'\', ' +
  'colorHex TEXT NOT NULL DEFAULT \'auto\', ' +
  'iconSystemName TEXT, ' +
  'startDate INTEGER, ' +
  'endDate INTEGER, ' +
  'startDatePreciseToHour INTEGER NOT NULL DEFAULT 0, ' +
  'endDatePreciseToHour INTEGER NOT NULL DEFAULT 0, ' +
  'createdAt INTEGER NOT NULL, ' +
  'progressCountingMode TEXT NOT NULL DEFAULT \'allTasks\')';

const CREATE_TASK = 'CREATE TABLE IF NOT EXISTS task (' +
  'id TEXT PRIMARY KEY, ' +
  'name TEXT NOT NULL DEFAULT \'\', ' +
  'colorHex TEXT, ' +
  'iconSystemName TEXT, ' +
  'type TEXT NOT NULL DEFAULT \'single\', ' +
  'status TEXT NOT NULL DEFAULT \'notDone\', ' +
  'totalAmount REAL NOT NULL DEFAULT 0, ' +
  'currentAmount REAL NOT NULL DEFAULT 0, ' +
  'startDate INTEGER, ' +
  'endDate INTEGER, ' +
  'reminderDate INTEGER, ' +
  'repeatRule TEXT, ' +
  'customWeekdaysRaw TEXT, ' +
  'createdAt INTEGER NOT NULL, ' +
  'sortOrder INTEGER NOT NULL DEFAULT 0, ' +
  'parentTaskId TEXT, ' +
  'goalId TEXT)';

const CREATE_CHAT = 'CREATE TABLE IF NOT EXISTS ai_chat_session (' +
  'id TEXT PRIMARY KEY, ' +
  'title TEXT NOT NULL DEFAULT \'\', ' +
  'createdAt INTEGER NOT NULL, ' +
  'updatedAt INTEGER NOT NULL, ' +
  'messagesData TEXT NOT NULL DEFAULT \'\', ' +
  'messageCount INTEGER NOT NULL DEFAULT 0, ' +
  'attachmentName TEXT, ' +
  'attachmentText TEXT)';

const CREATE_SETTINGS = 'CREATE TABLE IF NOT EXISTS settings (' +
  'key TEXT PRIMARY KEY, ' +
  'value TEXT)';

export class Database {
  private static store: relationalStore.RdbStore | undefined = undefined;

  /** 初始化数据库（应用启动时调用一次） */
  static async init(context: common.Context): Promise<void> {
    if (Database.store !== undefined) {
      return;
    }
    const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    const ddl: string[] = [CREATE_GOAL, CREATE_TASK, CREATE_CHAT, CREATE_SETTINGS];
    for (const sql of ddl) {
      await store.executeSql(sql);
    }
    Database.store = store;
  }

  static getStore(): relationalStore.RdbStore {
    if (Database.store === undefined) {
      throw new Error('Tick 数据库尚未初始化，请先调用 Database.init(context)');
    }
    return Database.store;
  }
}