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
    Column() {
      this.page()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  page() {
    Column() {
      // 顶部栏（扁平 56，与首页一致）
      Row({ space: D.spaceXs }) {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([this.tPrimary()])
        }
        .width(44)
        .height(44)
        .borderRadius(D.radiusPill)
        .backgroundColor(Color.Transparent)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => router.back())

        Text(I18n.t('ai.chatTitle'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Button() {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(20)
            .fontColor([this.tPrimary()])
        }
        .width(44)
        .height(44)
        .borderRadius(D.radiusPill)
        .backgroundColor(Color.Transparent)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onClick(() => this.attach())
      }
      .width('100%')
      .height(56)
      .padding({ left: D.spaceSm, right: D.spaceSm })

      // 显示选中的附件名（卡片内同心圆角）
      if (this.attachmentName.length > 0) {
        Row({ space: D.spaceXs }) {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(16)
            .fontColor([$r('sys.color.brand')])
          Text(this.attachmentName)
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Button() {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(14)
              .fontColor([this.tTertiary()])
          }
          .width(28)
          .height(28)
          .borderRadius(D.radiusPill)
          .backgroundColor(Color.Transparent)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onClick(() => {
            this.attachmentName = ''
            this.attachmentText = undefined
          })
        }
        .width('100%')
        .padding({ left: D.spaceMd, right: D.spaceXs, top: D.spaceXs, bottom: D.spaceXs })
        .margin({ left: D.spaceMd, right: D.spaceMd, top: D.spaceSm })
        .borderRadius(D.radiusL)
        .backgroundColor($r('sys.color.comp_background_list_card'))
      }

      // 消息列表
      List({ space: D.spaceMd }) {
        ForEach(this.messages, (msg: ChatMessage) => {
          ListItem() {
            this.messageBubble(msg)
          }
          .transition(TransitionEffect.OPACITY
            .animation({ duration: D.animNormal, curve: Curve.EaseInOut })
            .combine(TransitionEffect.translate({ y: 10 })))
        }, (msg: ChatMessage) => msg.id)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd })
      .scrollBar(BarState.Off)

      // 输入区（底部扁平卡片）
      Row({ space: D.spaceXs }) {
        TextInput({ placeholder: I18n.t('ai.input'), text: this.inputText })
          .layoutWeight(1)
          .height(44)
          .borderRadius(D.radiusM)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor(this.tPrimary())
          .onChange((v: string) => { this.inputText = v })
          .onSubmit(() => this.send())
        Button() {
          SymbolGlyph($r('sys.symbol.paperplane_fill'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_on_primary')])
        }
        .width(44)
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor($r('sys.color.brand'))
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
        .onClick(() => this.send())
      }
      .width('100%')
      .padding(D.spaceSm)
      .margin({ left: D.spaceMd, right: D.spaceMd, bottom: D.spaceSm })
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(D.radiusXl)

      if (this.busy) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('sys.color.brand'))
          Text(I18n.t('ai.sending'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
        }
        .padding({ bottom: D.spaceSm })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  messageBubble(msg: ChatMessage) {
    Row({ space: D.spaceXs }) {
      if (msg.role === 'assistant') {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(28)
            .height(28)
            .fill($r('sys.color.comp_background_tertiary'))
          SymbolGlyph($r('sys.symbol.wand_and_stars'))
            .fontSize(16)
            .fontColor([$r('sys.color.brand')])
        }
        .margin({ top: D.spaceXs })
      } else {
        Blank()
      }

      if (msg.role === 'user') {
        Column() {
          Text(msg.text)
            .fontSize(D.fontSizeBody)
            .fontColor($r('sys.color.font_on_primary'))
            .lineHeight(22)
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .borderRadius({ topLeft: D.radiusL, topRight: D.radiusL, bottomLeft: D.radiusL, bottomRight: D.radiusS })
        .backgroundColor($r('sys.color.brand'))
      } else {
        Column() {
          Text(msg.text)
            .fontSize(D.fontSizeBody)
            .fontColor(this.tPrimary())
            .lineHeight(22)
        }
        .constraintSize({ maxWidth: '78%' })
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .borderRadius({ topLeft: D.radiusL, topRight: D.radiusL, bottomLeft: D.radiusS, bottomRight: D.radiusL })
        .backgroundColor($r('sys.color.comp_background_list_card'))
      }

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
    const uriList: string[] = result
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
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.t('ai.attachParseFailed')
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
      const msg = err !== undefined && err.message !== undefined ? err.message : I18n.t('ai.requestFailed')
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
    return I18n.t('ai.done')
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
      this.session = new AIChatSession(I18n.t('ai.chatTitle'))
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

  private tPrimary(): string {
    return this.pal().textPrimary
  }

  private tSecondary(): string {
    return this.pal().textSecondary
  }

  private tTertiary(): string {
    return this.pal().textTertiary
  }
}