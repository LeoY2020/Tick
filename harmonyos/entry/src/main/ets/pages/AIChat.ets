import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import { ChatMessage, TaskNode, AIChatSession } from '../model/ChatModels';
import { TaskItem } from '../model/TaskItem';
import { SettingsModel } from '../model/Settings';
import { SettingsStore, ChatRepository, TaskRepository } from '../data/Repositories';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { I18n } from '../model/I18n';
import { AIService, AIServiceError } from '../services/AIService';
import { DocumentTextExtractor } from '../services/DocumentTextExtractor';
import { Theme, ThemePalette, DesignTokens } from '../theme/DesignTokens';

const D = DesignTokens;

/** AI 对话页：多轮聊天 + 可选附件解析 + 生成任务写入当前目标 */
@Entry
@Component
struct AIChat {
  build() {
    this.page()
  }

  @Builder
  page() {
    Column() {
      // 顶部栏
      Row() {
        Button(I18n.L('‹ 返回', '‹ Back'))
          .fontSize(D.fontSizeBody2)
          .fontColor(this.tPrimary())
          .backgroundColor(Color.Transparent)
          .onClick(() => router.back())
        Blank()
        Text(I18n.L('AI 对话', 'AI Chat'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
        Blank()
        Button(I18n.L('附件', 'Attach'))
          .fontSize(D.fontSizeBody2)
          .fontColor(Color.White)
          .backgroundColor(D.colorPrimary)
          .height(32)
          .borderRadius(D.radiusPill)
          .padding({ left: D.spaceMd, right: D.spaceMd })
          .onClick(() => this.attach())
      }.width('100%').padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd, bottom: D.spaceSm })

      // 显示选中的附件名
      if (this.attachmentName.length > 0) {
        Text(`${I18n.L('附件', 'Attach')}: ${this.attachmentName}`)
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: D.spaceLg, right: D.spaceLg })
      }

      // 消息列表
      List({ space: D.spaceMd }) {
        ForEach(this.messages, (msg: ChatMessage) => {
          ListItem() {
            this.messageBubble(msg)
          }
        }, (msg: ChatMessage) => msg.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd })
      .scrollBar(BarState.Off)

      // 输入区
      Row({ space: D.spaceSm }) {
        TextInput({ placeholder: I18n.L('输入消息…', 'Type a message…'), text: this.inputText })
          .layoutWeight(1)
          .height(42)
          .borderRadius(D.radiusPill)
          .backgroundColor(this.card())
          .fontColor(this.tPrimary())
          .onChange((v: string) => { this.inputText = v })
          .onSubmit(() => this.send())
        Button(I18n.L('发送', 'Send'))
          .height(42)
          .borderRadius(D.radiusPill)
          .backgroundColor(D.colorPrimary)
          .fontColor(Color.White)
          .padding({ left: D.spaceLg, right: D.spaceLg })
          .onClick(() => this.send())
      }.width('100%').padding(D.spaceMd)

      if (this.busy) {
        Text(I18n.L('AI 思考中…', 'AI is thinking…'))
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
          .padding({ bottom: D.spaceSm })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }

  @Builder
  messageBubble(msg: ChatMessage) {
    Row() {
      if (msg.role === 'user') {
        Blank()
      }
      Column() {
        Text(msg.text)
          .fontSize(D.fontSizeBody)
          .backgroundColor(msg.role === 'user' ? D.colorPrimary : this.card())
          .fontColor(msg.role === 'user' ? Color.White : this.tPrimary())
          .padding(D.spaceMd)
          .borderRadius(D.radiusL)
      }
      .constraintSize({ maxWidth: '80%' })
      if (msg.role === 'assistant') {
        Blank()
      }
    }
    .width('100%')
  }

  // ===== 状态 =====
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State attachmentName: string = ''
  @State busy: boolean = false
  @State settings: SettingsModel = new SettingsModel()
  @State colorScheme: 'system' | 'light' | 'dark' = 'system'

  private attachmentText: string | undefined = undefined
  private goalId: string = ''
  private session: AIChatSession | undefined = undefined

  aboutToAppear(): void {
    this.load()
  }

  async load(): Promise<void> {
    this.settings = await SettingsStore.load()
    I18n.setLanguage(this.settings.language)
    this.colorScheme = this.settings.colorScheme

    // 读取跳转参数中的目标
    const params = router.getParams() as Record<string, string>
    this.goalId = params !== undefined && params !== null && params['goalId'] !== undefined ? params['goalId'] : ''
    if (this.goalId.length === 0) {
      const goals = await AppViewModel.loadGoals()
      if (goals.length > 0) {
        this.goalId = goals[0].id
      }
    }

    // 恢复上次会话
    const sessions = await ChatRepository.list()
    if (sessions.length > 0) {
      this.session = sessions[0]
      const parsed = this.parseMessages(sessions[0].messagesData)
      this.messages = parsed
      this.attachmentText = sessions[0].attachmentText
      this.attachmentName = sessions[0].attachmentName === undefined ? '' : (sessions[0].attachmentName as string)
    }
  }

  private parseMessages(data: string): ChatMessage[] {
    if (data === undefined || data === null || data.length === 0) {
      return []
    }
    try {
      return JSON.parse(data) as ChatMessage[]
    } catch (e) {
      return []
    }
  }

  async attach(): Promise<void> {
    const hostCtx = this.getUIContext().getHostContext()
    if (hostCtx === undefined) {
      return
    }
    const documentPicker = new picker.DocumentViewPicker(hostCtx as common.Context)
    const result = await documentPicker.select({ maxSelectNumber: 1 })
    const uriList: string[] = result.uri
    const uri = (uriList !== undefined && uriList.length > 0) ? uriList[0] : ''
    if (uri === undefined || uri.length === 0) {
      return
    }
    try {
      const text = await DocumentTextExtractor.extractText(uri)
      this.attachmentText = text
      this.attachmentName = this.fileNameOf(uri)
    } catch (e) {
      const err = e as Error
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.L('附件解析失败', 'Failed to parse attachment')
      promptAction.showToast({ message: msg })
      // 友好提示:PDF 等格式解析失败
    }
  }

  private fileNameOf(uri: string): string {
    const idx = uri.lastIndexOf('/')
    return idx >= 0 ? uri.substring(idx + 1) : uri
  }

  async send(): Promise<void> {
    const text = this.inputText.trim()
    if (text.length === 0) {
      return
    }
    if (this.busy) {
      return
    }
    this.inputText = ''
    const userMsg: ChatMessage = this.makeMessage('user', text)
    this.messages.push(userMsg)
    this.busy = true
    try {
      const reply = await AIService.chatReply(this.history(), this.attachmentText, this.settings)
      // 生成任务：写入当前目标（不展示），仅展示 message
      if (reply.shouldGenerateTasks) {
        const cleanTasks = this.filterEmpty(reply.tasks)
        if (cleanTasks.length > 0) {
          await this.writeTasks(cleanTasks)
        }
      }
      const replyText = reply.message.length > 0 ? reply.message : this.defaultReplyText()
      const assistantMsg: ChatMessage = this.makeMessage('assistant', replyText)
      this.messages.push(assistantMsg)
      await this.persist()
    } catch (e) {
      const err = e as AIServiceError
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.L('请求失败', 'Request failed')
      const errMsg: ChatMessage = this.makeMessage('assistant', msg)
      this.messages.push(errMsg)
      await this.persist()
    } finally {
      this.busy = false
    }
  }

  private history(): ChatMessage[] {
    const out: ChatMessage[] = []
    for (const m of this.messages) {
      out.push(m)
    }
    return out
  }

  private makeMessage(role: 'user' | 'assistant', text: string): ChatMessage {
    return {
      id: this.randomId(),
      role: role,
      text: text,
      createdAt: Date.now()
    }
  }

  private randomId(): string {
    return 'm_' + Date.now().toString() + '_' + Math.floor(Math.random() * 100000).toString()
  }

  private defaultReplyText(): string {
    return I18n.L('已完成生成', 'Done')
  }

  private filterEmpty(nodes: TaskNode[]): TaskNode[] {
    const out: TaskNode[] = []
    for (const n of nodes) {
      if (n !== undefined && n.name !== undefined && n.name.trim().length > 0) {
        out.push(n)
      }
    }
    return out
  }

  private async writeTasks(nodes: TaskNode[]): Promise<void> {
    if (this.goalId.length === 0) {
      return
    }
    const tasks = this.nodesToTasks(nodes)
    await TaskRepository.insertTree(tasks, this.goalId, undefined)
  }

  private nodesToTasks(nodes: TaskNode[]): TaskItem[] {
    const out: TaskItem[] = []
    for (const n of nodes) {
      const t = new TaskItem(n.name === undefined ? '' : n.name)
      const children = n.children === undefined ? [] : n.children
      t.subtasks = this.nodesToTasks(children)
      out.push(t)
    }
    return out
  }

  private async persist(): Promise<void> {
    if (this.session === undefined) {
      this.session = new AIChatSession('AI 对话')
    }
    this.session.messagesData = JSON.stringify(this.messages)
    this.session.messageCount = this.messages.length
    this.session.attachmentText = this.attachmentText
    this.session.attachmentName = this.attachmentName.length > 0 ? this.attachmentName : undefined
    this.session.updatedAt = Date.now()
    await ChatRepository.save(this.session)
  }

  // ===== 主题辅助 =====
  private isDark(): boolean {
    return Theme.dark(this.colorScheme)
  }

  private pal(): ThemePalette {
    return Theme.palette(this.isDark())
  }

  private bg(): string {
    return this.pal().bg
  }

  private card(): string {
    return this.pal().card
  }

  private tPrimary(): string {
    return this.pal().textPrimary
  }

  private tSecondary(): string {
    return this.pal().textSecondary
  }
}