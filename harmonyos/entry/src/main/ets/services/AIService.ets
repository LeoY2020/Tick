import common from '@ohos.app.ability.common';
import http from '@ohos.net.http';
import Want from '@ohos.app.ability.Want';
import { ChatMessage, TaskNode, ChatReply, ChatEnvelope } from '../model/ChatModels';
import { SettingsModel } from '../model/Settings';
import { genId, now } from '../model/Util';

/**
 * AI 聊天系统提示词：要求输出 JSON envelope（任务入库 + 展示文字），由 AI 自行判断是否生成任务。
 * 生成任务的两类依据：①文档附件正文（用户消息"附件内容："之后）；②用户在纯对话中描述的需求。
 */
const CHAT_SYSTEM_PROMPT: string =
  '你是一个严谨的中文任务规划助手。你可以依据以下两类信息来生成具体、可执行、有信息量的分层任务清单：\n' +
  '1. 文档附件内容（通常在用户消息的"附件内容："之后）：从中提炼真实要点建任务，按章节、核心观点、待办事项拆分。\n' +
  '2. 用户在对话中描述的任务与计划：即使没有附件，也依据对话上下文，把用户提出的需求、事项、时间安排等整理成分层任务树。\n\n' +
  '硬性要求：\n' +
  '1. 任务名要具体明确（如"核对第三章数据""完成市场分析草稿"），严禁生成"了解xxx""阅读附件""整理要点"这类空泛无信息的任务。\n' +
  '2. 一级任务概括主题，二级任务给出具体动作或子步骤，层级嵌套。\n' +
  '3. 只要用户明确要求"生成/整理任务"（无论仅提供附件、还是仅在对话中描述需求），都应 generate=true 并基于可用信息生成任务树。\n' +
  '4. 仅当既没有附件正文、也没有明确的对话需求、实在无法提炼时，才返回 generate=false 并说明原因。\n\n' +
  '你必须严格只输出一个 JSON 对象，不要输出 markdown 代码块，也不要输出 JSON 以外的任何文字：\n' +
  '1. 用户要求生成/整理任务且能提炼要点时，输出：\n' +
  '{"generate": true, "tasks": [{"name":"一级任务","children":[{"name":"二级任务"}]}], "message": "给用户看的一句话中文说明"}\n' +
  '2. 用户要求生成任务、但既无附件正文也无明确对话需求、无法生成有意义任务时，输出：\n' +
  '{"generate": false, "message": "我目前还缺少足够的信息来生成有意义的任务。你可以上传带文字的文本/Markdown，或在对话里描述你想规划的事项。"}\n' +
  '3. 其他普通闲聊（未要求生成任务）时，输出：\n' +
  '{"generate": false, "message": "你的回复文字"}';

export interface OpenAIMessage {
  role: string;
  content: string;
}

export interface OpenAIRequestBody {
  model: string;
  messages: OpenAIMessage[];
}

export interface OpenAIChoiceMessage {
  role: string;
  content: string;
}

export interface OpenAIChoice {
  message: OpenAIChoiceMessage;
}

export interface OpenAIResponse {
  choices: OpenAIChoice[];
}

export interface ProviderConfig {
  url: string;
  modelId: string;
}

export class AIServiceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AIServiceError';
  }
}

/**
 * 华为「小艺」（盘古大模型）接入点。
 *
 * 【需要华为开发者证书 / 资质说明】
 * 小艺 / 盘古大模型属于华为移动服务（HMS）AI 能力，正式接入前需要：
 *   1. 华为开发者账号，并在 AppGallery Connect 创建应用、获取签名证书（*.p12 / *.cer）；
 *   2. 开通「智慧助手 / 盘古大模型」相关 Kit 的授权与配额；
 *   3. 在代码中替换下方的 bundleName / abilityName / action 为 AGC 分配的真实值，
 *      并通过 HMS Core 的意图路由或 AIWidget 唤起小艺。
 * 上述任一条件未满足时，本类返回「未授权」，应用自动回退到用户自配的 OpenAI 兼容 API。
 */
export class HuaweiAssistant {
  /** 是否已具备华为开发者资质与授权（此处为占位实现，运行时恒为 false） */
  static hasDeveloperCredentials(): boolean {
    // TODO(华为开发者)：接入真实授权判断后替换返回值
    return false;
  }

  /** 调用小艺/盘古生成回复（需授权；未授权时直接抛出，由上层回退） */
  static async chatCompletion(history: ChatMessage[], settings: SettingsModel): Promise<string> {
    throw new AIServiceError('小艺（盘古）通道尚未接入：缺少华为开发者证书与 AGC 授权。');
  }

  /** 小艺快捷入口：通过意图路由唤起小艺智能体（占位，需 AGC 授权后替换） */
  static async openQuickEntry(context: common.UIAbilityContext): Promise<boolean> {
    const want: Want = {
      bundleName: 'com.huawei.assistant',          // 占位：小艺主程序包名，以 AGC 授权为准
      abilityName: 'com.huawei.assistant.MainAbility', // 占位
      action: 'ohos.want.action.viewData',         // 占位：意图动作
      parameters: {}
    };
    try {
      await context.startAbility(want);
      return true;
    } catch (e) {
      return false;
    }
  }
}

export class AIService {
  /** 与 AI 聊天，返回结构化结果（AI 自行判断是否生成任务） */
  static async chatReply(
    history: ChatMessage[],
    attachmentText: string | undefined,
    settings: SettingsModel
  ): Promise<ChatReply> {
    const merged = AIService.mergeHistory(history, attachmentText);
    if (merged.length === 0) {
      throw new AIServiceError('模型未生成有效内容');
    }
    let raw = '';
    if (settings.aiModel === 'xiaoyi') {
      // [小艺/盘古] 优先；未授权时回退 OpenAI 兼容 API
      raw = await AIService.requestViaXiaoYiOrFallback(merged, settings);
    } else {
      raw = await AIService.cloudRequest(merged, settings);
    }
    return AIService.parseChatReply(raw);
  }

  // MARK: - [小艺接入点 + 回退逻辑]

  private static async requestViaXiaoYiOrFallback(
    history: ChatMessage[],
    settings: SettingsModel
  ): Promise<string> {
    if (HuaweiAssistant.hasDeveloperCredentials()) {
      // 小艺已授权：走盘古大模型；若内部失败，也回退
      try {
        return await HuaweiAssistant.chatCompletion(history, settings);
      } catch (e) {
        // 落入下方回退逻辑
      }
    }
    // [回退逻辑] 未授权 → 使用用户自配的 OpenAI 兼容 API
    const base = (settings.baseUrl ?? '').trim();
    const modelName = (settings.modelName ?? '').trim();
    const apiKey = (settings.apiKey ?? '').trim();
    if (base.length === 0 || modelName.length === 0 || apiKey.length === 0) {
      throw new AIServiceError('小艺（盘古）尚未授权，且未配置 OpenAI 兼容 API 的 Base URL / 模型名 / API Key。请在 设置 → AI 模型 中配置后再试。');
    }
    const url = AIService.normalizeChatCompletionsUrl(base);
    return AIService.sendOpenAIRequest(url, modelName, apiKey, history);
  }

  // MARK: - 云模型（OpenAI 兼容）

  private static async cloudRequest(history: ChatMessage[], settings: SettingsModel): Promise<string> {
    const apiKey = (settings.apiKey ?? '').trim();
    if (apiKey.length === 0) {
      throw new AIServiceError('请先在 设置 → AI 模型 中填写该模型的 API Key');
    }
    const provider = AIService.resolveProvider(settings);
    return AIService.sendOpenAIRequest(provider.url, provider.modelId, apiKey, history);
  }

  private static resolveProvider(settings: SettingsModel): ProviderConfig {
    switch (settings.aiModel) {
      case 'qwen':
        return { url: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', modelId: 'qwen-plus' };
      case 'deepseek':
        return { url: 'https://api.deepseek.com/chat/completions', modelId: 'deepseek-chat' };
      case 'chatgpt':
        return { url: 'https://api.openai.com/v1/chat/completions', modelId: 'gpt-4o-mini' };
      case 'yuanbao':
        return { url: 'https://api.hunyuan.cloud.tencent.com/v1/chat/completions', modelId: 'hunyuan-turbo' };
      case 'glm':
        return { url: 'https://open.bigmodel.cn/api/paas/v4/chat/completions', modelId: 'glm-4-flash' };
      case 'kimi':
        return { url: 'https://api.moonshot.cn/v1/chat/completions', modelId: 'moonshot-v1-8k' };
      case 'ernie':
        return { url: 'https://qianfan.baidubce.com/v2/chat/completions', modelId: 'ernie-4.0-turbo-8k' };
      default:
        break;
    }
    // custom：使用用户自配地址与模型名
    const base = (settings.baseUrl ?? '').trim();
    const modelId = (settings.modelName ?? '').trim();
    if (base.length === 0) {
      throw new AIServiceError('请先在 设置 → AI 模型 中填写自定义 Base URL');
    }
    return { url: AIService.normalizeChatCompletionsUrl(base), modelId };
  }

  private static normalizeChatCompletionsUrl(base: string): string {
    let b = base.trim();
    if (b.length === 0) {
      return b;
    }
    if (b.endsWith('/chat/completions')) {
      return b;
    }
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b + '/chat/completions';
  }

  private static async sendOpenAIRequest(
    url: string,
    modelId: string,
    apiKey: string,
    history: ChatMessage[]
  ): Promise<string> {
    const messages: OpenAIMessage[] = [];
    messages.push({ role: 'system', content: CHAT_SYSTEM_PROMPT });
    for (const m of history) {
      messages.push({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text });
    }
    const body: OpenAIRequestBody = { model: modelId, messages: messages };

    const header: Record<string, string> = {};
    header['Content-Type'] = 'application/json';
    header['Authorization'] = 'Bearer ' + apiKey;

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 30000,
      readTimeout: 60000
    };

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, options);
      const status: number = response.responseCode;
      if (status < 200 || status >= 300) {
        throw new AIServiceError('网络请求失败：HTTP ' + status.toString());
      }
      const raw: string = response.result as string;
      return AIService.parseOpenAIResponse(raw);
    } finally {
      httpRequest.destroy();
    }
  }

  private static parseOpenAIResponse(raw: string): string {
    let data: OpenAIResponse | undefined = undefined;
    try {
      data = JSON.parse(raw) as OpenAIResponse;
    } catch (e) {
      throw new AIServiceError('模型服务返回了异常响应');
    }
    if (data === undefined || data === null || data.choices === undefined || data.choices.length === 0) {
      throw new AIServiceError('模型服务返回了异常响应');
    }
    const content = data.choices[0].message.content;
    if (content === undefined || content === null || content.trim().length === 0) {
      throw new AIServiceError('模型未生成有效内容');
    }
    return content;
  }

  // MARK: - 提示词 / 解析

  /** 把附件内容注入为对话首条"用户"消息 */
  static mergeHistory(history: ChatMessage[], attachmentText: string | undefined): ChatMessage[] {
    const result: ChatMessage[] = [];
    if (attachmentText !== undefined && attachmentText.trim().length > 0) {
      result.push({ id: genId(), role: 'user', text: '附件内容：\n' + attachmentText.trim(), createdAt: now() });
    }
    for (const m of history) {
      result.push(m);
    }
    return result;
  }

  /** 解析 chatReply 的 JSON envelope；失败回退为普通文字展示 */
  static parseChatReply(raw: string): ChatReply {
    const cleaned = AIService.stripCodeFences(raw).trim();
    const obj = AIService.jsonObjectFrom(cleaned);
    if (obj.length > 0) {
      try {
        const env = JSON.parse(obj) as ChatEnvelope;
        const generate = env.generate === true;
        const tasks: TaskNode[] = env.tasks === undefined ? [] : env.tasks;
        const message: string = env.message === undefined ? '' : env.message;
        if (generate) {
          const nodes: TaskNode[] = tasks.filter((n: TaskNode) => n.name !== undefined && n.name.trim().length > 0);
          const replyMessage = message.length > 0 ? message : ('已为你生成 ' + nodes.length + ' 个任务。');
          return { shouldGenerateTasks: true, tasks: nodes, message: replyMessage };
        }
        if (message.length > 0) {
          return { shouldGenerateTasks: false, tasks: [], message };
        }
      } catch (e) {
        // 解析失败：回落为普通文字
      }
    }
    return { shouldGenerateTasks: false, tasks: [], message: raw };
  }

  /** 抽取文本中第一个 '{' 到最后一个 '}' 的 JSON 对象子串 */
  static jsonObjectFrom(text: string): string {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start < 0 || end < 0 || start >= end) {
      return '';
    }
    return text.substring(start, end + 1);
  }

  /** 去掉 ``` 代码围栏 */
  static stripCodeFences(text: string): string {
    const lines: string[] = text.split('\n');
    if (lines.length > 0 && lines[0].indexOf('```') >= 0) {
      lines.shift();
    }
    if (lines.length > 0 && lines[lines.length - 1].indexOf('```') >= 0) {
      lines.pop();
    }
    return lines.join('\n');
  }
}