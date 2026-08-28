import { genId, now } from './Util';

/** 一条对话消息（AI 聊天 / 生成任务共用） */
export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  createdAt: number;
}

/** AI 生成的任务树节点（宽容解码：缺字段不失败） */
export interface TaskNode {
  name: string;
  children: TaskNode[];
}

/** AI 回复的结构化结果 */
export interface ChatReply {
  shouldGenerateTasks: boolean;
  tasks: TaskNode[];
  message: string;
}

/** 模型输出 JSON envelope（宽容解析：字段可缺省） */
export interface ChatEnvelope {
  generate?: boolean;
  tasks?: TaskNode[];
  message?: string;
}

/** AI 聊天历史会话（持久化到 RDB） */
export class AIChatSession {
  id: string = '';
  /** 会话标题（取首条用户消息摘要） */
  title: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  /** 消息列表的 JSON 编码（[ChatMessage]） */
  messagesData: string = '';
  messageCount: number = 0;
  attachmentName: string | undefined = undefined;
  attachmentText: string | undefined = undefined;

  constructor(title: string = '') {
    this.id = genId();
    this.title = title;
    this.createdAt = now();
    this.updatedAt = now();
  }
}