import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';
import { SettingsModel } from '../model/Settings';
import { SettingsStore } from '../data/Repositories';
import { AppViewModel, TaskRow, GoalProgressView } from '../viewmodel/AppViewModel';
import { I18n } from '../model/I18n';
import { CountdownFormatter } from '../services/CountdownFormatter';
import { ReminderService } from '../services/ReminderService';
import { TaskType, TaskStatus, RepeatRule } from '../model/Enums';
import { DesignTokens, COLOR_PALETTE, PaletteColor, Theme, ThemePalette } from '../theme/DesignTokens';

const D = DesignTokens;

const WEEKDAY_LABELS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

/** 任务编辑面板状态 */
class TaskEditBuffer {
  mode: 'new' | 'newChild' | 'edit' = 'new';
  id: string = '';
  goalId: string = '';
  parentId: string | undefined = undefined;
  name: string = '';
  type: TaskType = 'single';
  status: TaskStatus = 'notDone';
  totalAmount: number = 0;
  currentAmount: number = 0;
  colorHex: string | undefined = undefined;
  hasReminder: boolean = false;
  reminderMs: number = Date.now();
  repeatRule: RepeatRule = 'never';
  weekdays: number[] = [];
}

/** 目标编辑面板状态 */
class GoalEditBuffer {
  isNew: boolean = true;
  id: string = '';
  name: string = '';
  colorHex: string = 'auto';
  countingMode: 'allTasks' | 'leafTasks' = 'allTasks';
}

@Entry
@Component
struct Index {
  build() {
    this.page()
  }

  // ===== 页面根 =====
  @Builder
  page() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        this.headerBar()
        if (this.selectedGoalId.length === 0) {
          this.emptyState()
        } else {
          this.goalHeader()
          this.goalProgressArea()
          Column() {
            List({ space: D.spaceSm }) {
              ForEach(this.buildRows(), (row: TaskRow) => {
                ListItem() {
                  this.taskRow(row)
                }
                .bindContextMenu(this.rowMenu(row), ResponseType.LongPress)
              }, (row: TaskRow) => row.task.id)
            }
            .layoutWeight(1)
            .width('100%')
            .divider({ strokeWidth: 0.5, color: this.dividerC() })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.currentBackground())

      // 底部添加任务按钮
      if (this.selectedGoalId.length > 0) {
        Button() {
          Text('+')
            .fontSize(28)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .width(52)
        .height(52)
        .borderRadius(D.radiusPill)
        .backgroundColor(D.colorPrimary)
        .shadow({ radius: 12, color: '#330A59F7', offsetY: 4 })
        .margin({ bottom: 24, right: 20 })
        .onClick(() => this.openAddTopTask())
      }

      // 目标抽屉侧边栏
      if (this.sidebarShown) {
        this.sidebar()
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.taskSheetVisible, this.taskSheetBuilder(), {
      height: 560,
      showClose: true,
      dragBar: true
    })
    .bindSheet($$this.goalSheetVisible, this.goalSheetBuilder(), {
      height: 520,
      showClose: true,
      dragBar: true
    })
  }

  // ===== 顶部导航栏 =====
  @Builder
  headerBar() {
    Row() {
      Row() {
        Button() {
          Text('☰')
            .fontSize(22)
            .fontColor(this.tPrimary())
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.sidebarShown = true
        })
      }.layoutWeight(1)

      Column() {
        if (this.selectedGoalName.length > 0) {
          Text(this.selectedGoalName)
            .fontSize(D.fontSizeTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tPrimary())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text('Tick')
            .fontSize(D.fontSizeTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tPrimary())
        }
      }
      .layoutWeight(2)
      .alignItems(HorizontalAlign.Center)

      Row({ space: 2 }) {
        Button() {
          Text('AI')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .borderRadius(D.radiusPill)
        .backgroundColor(D.colorPrimary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/AIChat', params: { goalId: this.selectedGoalId } })
        })
        Button() {
          Text('⚙')
            .fontSize(20)
            .fontColor(this.tPrimary())
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Settings' })
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding({ left: D.spaceMd, right: D.spaceMd, top: D.spaceMd, bottom: D.spaceSm })
  }

  // ===== 空态 =====
  @Builder
  emptyState() {
    Column({ space: D.spaceMd }) {
      Text('🎯')
        .fontSize(52)
      Text(I18n.L('请先添加一个目标', 'Add a goal to start'))
        .fontSize(D.fontSizeBody)
        .fontColor(this.tSecondary())
      Button(I18n.L('添加目标', 'Add Goal'))
        .height(40)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .onClick(() => this.openAddGoal())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ===== 目标标题 + 倒计时 =====
  @Builder
  goalHeader() {
    Row() {
      Text(this.selectedGoalName)
        .fontSize(D.fontSizeTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tPrimary())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
      if (this.selectedEndDate !== undefined) {
        Column({ space: 2 }) {
          Text(I18n.L('剩余时间', 'Remaining'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tSecondary())
          if (CountdownFormatter.countdown(this.selectedEndDate, this.selectedEndPrecise) !== undefined) {
            Text(CountdownFormatter.countdown(this.selectedEndDate, this.selectedEndPrecise) as string)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(D.colorPrimary)
          }
          Text(CountdownFormatter.endDateLabel(this.selectedEndDate, this.selectedEndPrecise))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.tTertiary())
        }.alignItems(HorizontalAlign.End)
      }
    }
    .width('100%')
    .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm })
  }

  // ===== 目标总进度 =====
  @Builder
  goalProgressArea() {
    const p: GoalProgressView = this.computeProgress()
    Column({ space: 6 }) {
      Progress({ value: Math.min(p.fraction, 1) * 100, total: 100, type: ProgressType.Linear })
        .color(this.resolveColor(this.selectedGoalColor))
        .height(6)
        .borderRadius(3)
        .width('100%')
      Row() {
        Text(`${I18n.L('已完成', 'Done')} ${Math.round(p.completedWeight)} ${I18n.L('共', 'of')} ${p.totalItems} ${I18n.L('项', 'items')}`)
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
        Blank()
        Text(`${(Math.min(p.fraction, 1) * 100).toFixed(1)}%`)
          .fontSize(D.fontSizeCaption)
          .fontColor(this.tSecondary())
      }.width('100%')
    }
    .width('100%')
    .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
  }

  // ===== 单个任务行 =====
  @Builder
  taskRow(row: TaskRow) {
    Row({ space: D.spaceSm }) {
      // 展开箭头
      if (row.hasChildren) {
        Text(row.expanded ? '▾' : '▸')
          .fontSize(14)
          .fontColor(this.tSecondary())
          .width(18)
          .onClick(() => this.toggleExpand(row.task.id))
      } else {
        Blank().width(18)
      }
      // 颜色圆点
      Circle()
        .width(10)
        .height(10)
        .fill(this.resolveColor(AppViewModel.effectiveColor(row.task)))
      // 名称
      Text(row.task.name)
        .fontSize(D.fontSizeBody)
        .fontColor(this.isDeletedTask(row.task) ? this.tTertiary() : this.tPrimary())
        .opacity(this.isDeletedTask(row.task) ? 0.5 : 1)
        .decoration({ type: this.isDeletedTask(row.task) ? TextDecorationType.LineThrough : TextDecorationType.None })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      // 右侧状态 / 进度控件
      this.trailingControl(row)
    }
    .width('100%')
    .padding({ left: Math.min(row.depth * 18, 90), right: D.spaceMd, top: D.spaceSm, bottom: D.spaceSm })
    .margin({ left: D.spaceMd, right: D.spaceMd })
    .borderRadius(D.radiusM)
    .backgroundColor(this.currentCard())
  }

  // ===== 行尾控件 =====
  @Builder
  trailingControl(row: TaskRow) {
    if (row.task.type === 'single') {
      this.singleControl(row)
    } else {
      this.progressControl(row)
    }
  }

  // ===== 单项状态控件 =====
  @Builder
  singleControl(row: TaskRow) {
    const st: TaskStatus = AppViewModel.effectiveStatus(row.task)
    Column() {
      Text(this.statusSymbol(st))
        .fontSize(20)
        .fontColor(this.statusColor(st))
    }
    .width(36)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (!row.hasChildren) {
        this.cycleStatus(row.task)
      }
    })
  }

  // ===== 进度控件 =====
  @Builder
  progressControl(row: TaskRow) {
    const p = AppViewModel.effectiveProgress(row.task)
    Row({ space: 6 }) {
      if (!row.hasChildren) {
        Button('-')
          .width(24)
          .height(24)
          .fontSize(16)
          .fontColor(this.tPrimary())
          .backgroundColor(this.colorPressed())
          .onClick(() => this.adjustProgress(row.task, -1))
      }
      Text(`${Math.round(p.current)}/${Math.round(p.total)}`)
        .fontSize(D.fontSizeCaption)
        .fontColor(this.tSecondary())
      Progress({ value: p.total > 0 ? Math.min(p.current / p.total, 1) * 100 : 0, total: 100, type: ProgressType.Linear })
        .width(56)
        .height(4)
        .color(D.colorPrimary)
      if (!row.hasChildren) {
        Button('+')
          .width(24)
          .height(24)
          .fontSize(16)
          .fontColor(this.tPrimary())
          .backgroundColor(this.colorPressed())
          .onClick(() => this.adjustProgress(row.task, 1))
      }
    }
  }

  // ===== 行右键菜单 =====
  @Builder
  rowMenu(row: TaskRow) {
    Menu() {
      MenuItem({ content: I18n.L('编辑', 'Edit') })
        .onClick(() => this.openEditTask(row.task))
      MenuItem({ content: I18n.L('添加子任务', 'Add Subtask') })
        .onClick(() => this.openAddChild(row.task))
      MenuItem({ content: I18n.L('删除', 'Delete') })
        .onClick(() => this.confirmDelete(row.task))
    }
  }

  // ===== 目标抽屉侧边栏 =====
  @Builder
  sidebar() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 遮罩
      Column().width('100%').height('100%').backgroundColor('#40000000').onClick(() => { this.sidebarShown = false })
      // 面板
      Column() {
        Text(I18n.L('目标', 'Goals'))
          .fontSize(D.fontSizeTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.tPrimary())
          .width('100%')
          .margin({ bottom: D.spaceMd })
        List({ space: D.spaceSm }) {
          ForEach(this.goals, (g: Goal) => {
            ListItem() {
              Row() {
                Circle()
                  .width(10)
                  .height(10)
                  .fill(this.resolveColor(g.colorHex))
                Text(g.name)
                  .fontSize(D.fontSizeBody)
                  .fontColor(this.selectedGoalId === g.id ? D.colorPrimary : this.tPrimary())
                  .fontWeight(this.selectedGoalId === g.id ? FontWeight.Medium : FontWeight.Normal)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                if (this.selectedGoalId === g.id) {
                  Text('✓').fontSize(16).fontColor(D.colorPrimary)
                }
              }
              .width('100%')
              .padding(D.spaceSm)
              .borderRadius(D.radiusM)
              .backgroundColor(this.selectedGoalId === g.id ? '#140A59F7' : Color.Transparent)
              .onClick(() => {
                this.selectGoal(g.id)
                this.sidebarShown = false
              })
            }
            .swipeAction({ end: this.deleteGoalSwipe(g) })
          }, (g: Goal) => g.id)
        }
        .layoutWeight(1)
        .width('100%')

        Button(I18n.L('新建目标', 'New Goal'))
          .width('100%')
          .height(40)
          .borderRadius(D.radiusL)
          .backgroundColor(D.colorPrimary)
          .fontColor(Color.White)
          .margin({ top: D.spaceMd })
          .onClick(() => {
            this.sidebarShown = false
            this.openAddGoal()
          })
        Button(I18n.L('设置', 'Settings'))
          .width('100%')
          .height(40)
          .borderRadius(D.radiusL)
          .backgroundColor(this.colorPressed())
          .fontColor(this.tPrimary())
          .margin({ top: D.spaceSm })
          .onClick(() => {
            this.sidebarShown = false
            router.pushUrl({ url: 'pages/Settings' })
          })
      }
      .width(280)
      .height('100%')
      .padding(D.spaceLg)
      .backgroundColor(this.currentCard())
      .borderRadius({ topRight: D.radiusXl, bottomRight: D.radiusXl })
    }
  }

  @Builder
  deleteGoalSwipe(g: Goal) {
    Menu() {
      MenuItem({ content: I18n.L('删除目标', 'Delete Goal') })
        .onClick(() => this.confirmDeleteGoal(g))
      MenuItem({ content: I18n.L('编辑目标', 'Edit Goal') })
        .onClick(() => this.openEditGoal(g))
    }
  }

  // ===== 任务编辑面板 =====
  @Builder
  taskSheetBuilder() {
    Column({ space: D.spaceMd }) {
      TextInput({ placeholder: I18n.L('任务名称', 'Task name'), text: this.taskBuf.name })
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor(this.currentCard())
        .onChange((v: string) => { this.taskBuf.name = v })

      // 类型选择
      Row({ space: D.spaceSm }) {
        this.typeChip('single', I18n.L('单项', 'Single'))
        this.typeChip('progress', I18n.L('进度', 'Progress'))
      }.width('100%')

      if (this.taskBuf.type === 'progress') {
        Row({ space: D.spaceMd }) {
          Column({ space: 4 }) {
            Text(I18n.L('总量', 'Total')).fontSize(D.fontSizeCaption).fontColor(this.tSecondary())
            TextInput({ text: this.taskBuf.totalAmount.toString() })
              .type(InputType.Number)
              .height(40)
              .borderRadius(D.radiusM)
              .backgroundColor(this.currentCard())
              .onChange((v: string) => {
                this.taskBuf.totalAmount = Number.parseFloat(v)
                if (Number.isNaN(this.taskBuf.totalAmount)) { this.taskBuf.totalAmount = 0 }
              })
          }.layoutWeight(1)
          Column({ space: 4 }) {
            Text(I18n.L('当前', 'Current')).fontSize(D.fontSizeCaption).fontColor(this.tSecondary())
            TextInput({ text: this.taskBuf.currentAmount.toString() })
              .type(InputType.Number)
              .height(40)
              .borderRadius(D.radiusM)
              .backgroundColor(this.currentCard())
              .onChange((v: string) => {
                this.taskBuf.currentAmount = Number.parseFloat(v)
                if (Number.isNaN(this.taskBuf.currentAmount)) { this.taskBuf.currentAmount = 0 }
              })
          }.layoutWeight(1)
        }.width('100%')
      } else {
        Row({ space: D.spaceSm }) {
          Text(I18n.L('状态', 'Status')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary())
          this.statusChip('notDone', I18n.L('未完成', 'Not Done'))
          this.statusChip('done', I18n.L('完成', 'Done'))
          this.statusChip('deleted', I18n.L('删除', 'Deleted'))
        }.width('100%')
      }

      // 颜色
      Scroll() {
        Row({ space: D.spaceSm }) {
          ForEach(COLOR_PALETTE, (c: PaletteColor) => {
            Column() {
              Circle()
                .width(28)
                .height(28)
                .fill(c.hex)
              if (this.taskBuf.colorHex === c.hex) {
                Text('✓').fontSize(12).fontColor(Color.White).position({ x: 9, y: 5 })
              }
            }
            .width(32)
            .height(32)
            .onClick(() => { this.taskBuf.colorHex = c.hex })
          }, (c: PaletteColor) => c.hex)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .width('100%')
      .height(36)

      // 提醒
      Column({ space: D.spaceSm }) {
        Row() {
          Text(I18n.L('提醒', 'Reminder')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary())
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.taskBuf.hasReminder })
            .onChange((on: boolean) => { this.taskBuf.hasReminder = on })
        }.width('100%')
        if (this.taskBuf.hasReminder) {
          // 重复规则
          Row({ space: D.spaceSm }) {
            this.repeatChip('never', I18n.L('不重复', 'Once'))
            this.repeatChip('daily', I18n.L('每天', 'Daily'))
            this.repeatChip('weekly', I18n.L('每周', 'Weekly'))
            this.repeatChip('monthly', I18n.L('每月', 'Monthly'))
            this.repeatChip('custom', I18n.L('自定义', 'Custom'))
          }.width('100%')
          if (this.taskBuf.repeatRule === 'custom') {
            Row({ space: D.spaceSm }) {
              ForEach([1, 2, 3, 4, 5, 6, 7], (w: number) => {
                Text(WEEKDAY_LABELS[w - 1])
                  .fontSize(D.fontSizeCaption)
                  .fontColor(this.taskBuf.weekdays.indexOf(w) >= 0 ? Color.White : this.tPrimary())
                  .backgroundColor(this.taskBuf.weekdays.indexOf(w) >= 0 ? D.colorPrimary : this.colorPressed())
                  .width(34)
                  .height(34)
                  .borderRadius(D.radiusPill)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.toggleWeekday(w))
              }, (w: number) => w.toString())
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          }
        }
      }.width('100%')

      Button(I18n.L('保存', 'Save'))
        .width('100%')
        .height(44)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .margin({ top: D.spaceSm })
        .onClick(() => this.saveTaskEditor())
    }
    .padding(D.spaceLg)
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentBackground())
  }

  @Builder
  typeChip(t: TaskType, label: string) {
    Text(label)
      .fontSize(D.fontSizeBody2)
      .fontColor(this.taskBuf.type === t ? Color.White : this.tPrimary())
      .backgroundColor(this.taskBuf.type === t ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceLg, right: D.spaceLg, top: D.spaceSm, bottom: D.spaceSm })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.type = t })
  }

  @Builder
  statusChip(s: TaskStatus, label: string) {
    Text(label)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.taskBuf.status === s ? Color.White : this.tPrimary())
      .backgroundColor(this.taskBuf.status === s ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceMd, right: D.spaceMd, top: 4, bottom: 4 })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.status = s })
  }

  @Builder
  repeatChip(r: RepeatRule, label: string) {
    Text(label)
      .fontSize(D.fontSizeCaption)
      .fontColor(this.taskBuf.repeatRule === r ? Color.White : this.tPrimary())
      .backgroundColor(this.taskBuf.repeatRule === r ? D.colorPrimary : this.colorPressed())
      .padding({ left: D.spaceMd, right: D.spaceMd, top: 4, bottom: 4 })
      .borderRadius(D.radiusPill)
      .onClick(() => { this.taskBuf.repeatRule = r })
  }

  toggleWeekday(w: number): void {
    const idx = this.taskBuf.weekdays.indexOf(w)
    if (idx >= 0) {
      this.taskBuf.weekdays.splice(idx, 1)
    } else {
      this.taskBuf.weekdays.push(w)
    }
    this.revision++
  }

  // ===== 目标编辑面板 =====
  @Builder
  goalSheetBuilder() {
    Column({ space: D.spaceMd }) {
      TextInput({ placeholder: I18n.L('目标名称', 'Goal name'), text: this.goalBuf.name })
        .height(44)
        .borderRadius(D.radiusM)
        .backgroundColor(this.currentCard())
        .onChange((v: string) => { this.goalBuf.name = v })

      // 颜色
      Column({ space: D.spaceSm }) {
        Text(I18n.L('颜色', 'Color')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary()).width('100%')
        Scroll() {
          Row({ space: D.spaceSm }) {
            ForEach(COLOR_PALETTE, (c: PaletteColor) => {
              Column() {
                Circle()
                  .width(28)
                  .height(28)
                  .fill(c.hex)
                if (this.goalBuf.colorHex === c.hex) {
                  Text('✓').fontSize(12).fontColor(Color.White).position({ x: 9, y: 5 })
                }
              }
              .width(32)
              .height(32)
              .onClick(() => { this.goalBuf.colorHex = c.hex })
            }, (c: PaletteColor) => c.hex)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .height(36)
      }.width('100%')

      Column({ space: 4 }) {
        Text(I18n.L('进度统计模式', 'Progress counting')).fontSize(D.fontSizeBody2).fontColor(this.tSecondary()).width('100%')
        Row({ space: D.spaceSm }) {
          Text(I18n.L('全部任务', 'All tasks'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.goalBuf.countingMode === 'allTasks' ? Color.White : this.tPrimary())
            .backgroundColor(this.goalBuf.countingMode === 'allTasks' ? D.colorPrimary : this.colorPressed())
            .padding({ left: D.spaceMd, right: D.spaceMd, top: 6, bottom: 6 })
            .borderRadius(D.radiusPill)
            .onClick(() => { this.goalBuf.countingMode = 'allTasks' })
          Text(I18n.L('仅叶子任务', 'Leaf tasks only'))
            .fontSize(D.fontSizeCaption)
            .fontColor(this.goalBuf.countingMode === 'leafTasks' ? Color.White : this.tPrimary())
            .backgroundColor(this.goalBuf.countingMode === 'leafTasks' ? D.colorPrimary : this.colorPressed())
            .padding({ left: D.spaceMd, right: D.spaceMd, top: 6, bottom: 6 })
            .borderRadius(D.radiusPill)
            .onClick(() => { this.goalBuf.countingMode = 'leafTasks' })
        }.width('100%')
      }.width('100%')

      Button(I18n.L('保存', 'Save'))
        .width('100%')
        .height(44)
        .borderRadius(D.radiusL)
        .backgroundColor(D.colorPrimary)
        .fontColor(Color.White)
        .onClick(() => this.saveGoalEditor())
    }
    .padding(D.spaceLg)
    .width('100%')
    .height('100%')
    .backgroundColor(this.currentBackground())
  }

  // ===== 状态字段（非响应式，供 buildRows/渲染使用）=====
  private goals: Goal[] = []
  private currentTree: TaskItem[] = []
  private expanded: Set<string> = new Set<string>()
  private selectedGoalName: string = ''
  private selectedGoalColor: string = 'auto'
  private selectedEndDate: number | undefined = undefined
  private selectedEndPrecise: boolean = false
  private selectedCountingMode: 'allTasks' | 'leafTasks' = 'allTasks'
  private taskBuf: TaskEditBuffer = new TaskEditBuffer()
  private goalBuf: GoalEditBuffer = new GoalEditBuffer()
  private timer: number = 0

  // ===== 响应式字段 =====
  @State revision: number = 0
  @State selectedGoalId: string = ''
  @State sidebarShown: boolean = false
  @State taskSheetVisible: boolean = false
  @State goalSheetVisible: boolean = false
  @State colorScheme: 'system' | 'light' | 'dark' = 'system'

  aboutToAppear(): void {
    this.refreshGoals()
    this.loadSettings()
    // 每分钟刷新倒计时
    this.timer = setInterval(() => { this.revision++ }, 30000)
  }

  aboutToDisappear(): void {
    if (this.timer > 0) {
      clearInterval(this.timer)
    }
  }

  onPageShow(): void {
    this.refreshGoals()
    this.loadSettings()
  }

  async loadSettings(): Promise<void> {
    const s: SettingsModel = await SettingsStore.load()
    I18n.setLanguage(s.language)
    this.colorScheme = s.colorScheme
    this.revision++
  }

  async refreshGoals(): Promise<void> {
    const goals = await AppViewModel.loadGoals()
    this.goals = goals
    if (goals.length === 0) {
      this.selectedGoalId = ''
      this.currentTree = []
      this.revision++
      return
    }
    if (this.selectedGoalId.length === 0 || goals.findIndex((g: Goal) => g.id === this.selectedGoalId) < 0) {
      this.selectedGoalId = goals[0].id
    }
    await this.loadSelectedGoal(goals)
    this.revision++
  }

  private async loadSelectedGoal(goals: Goal[]): Promise<void> {
    const goal = goals.find((g: Goal) => g.id === this.selectedGoalId)
    if (goal === undefined) {
      this.currentTree = []
      return
    }
    this.selectedGoalName = goal.name
    this.selectedGoalColor = goal.colorHex
    this.selectedEndDate = goal.endDate
    this.selectedEndPrecise = goal.endDatePreciseToHour
    this.selectedCountingMode = goal.progressCountingMode
    this.currentTree = await AppViewModel.loadGoalTree(goal.id)
  }

  private async selectGoal(id: string): Promise<void> {
    this.selectedGoalId = id
    this.expanded = new Set<string>()
    await this.loadSelectedGoal(this.goals)
    this.revision++
  }

  // ===== 构建行与进度 =====
  private buildRows(): TaskRow[] {
    return AppViewModel.flatten(this.currentTree, this.expanded)
  }

  private computeProgress(): GoalProgressView {
    const temp = new Goal()
    temp.tasks = this.currentTree
    temp.progressCountingMode = this.selectedCountingMode
    return AppViewModel.goalProgress(temp)
  }

  private toggleExpand(id: string): void {
    if (this.expanded.has(id)) {
      this.expanded.delete(id)
    } else {
      this.expanded.add(id)
    }
    this.revision++
  }

  private cycleStatus(task: TaskItem): void {
    switch (task.status) {
      case 'notDone':
        task.status = 'done'
        break
      case 'done':
        task.status = 'halfDone'
        break
      case 'halfDone':
        task.status = 'deleted'
        break
      case 'deleted':
        task.status = 'notDone'
        break
    }
    AppViewModel.saveTask(task)  // fire and forget
    this.revision++
  }

  private adjustProgress(task: TaskItem, delta: number): void {
    const p = AppViewModel.effectiveProgress(task)
    let next = task.currentAmount + delta
    task.currentAmount = Math.min(Math.max(next, 0), task.totalAmount)
    AppViewModel.saveTask(task)
    this.revision++
  }

  private isDeletedTask(task: TaskItem): boolean {
    return AppViewModel.isDeleted(task)
  }

  private statusSymbol(s: TaskStatus): string {
    switch (s) {
      case 'done':
        return '●'
      case 'halfDone':
        return '◐'
      case 'deleted':
        return '🗑'
      default:
        return '○'
    }
  }

  private statusColor(s: TaskStatus): string {
    switch (s) {
      case 'done':
        return D.colorSuccess
      case 'halfDone':
        return D.colorWarning
      case 'deleted':
        return D.colorDanger
      default:
        return this.tTertiary()
    }
  }

  // ===== 编辑打开/保存 =====
  private openAddTopTask(): void {
    this.taskBuf.mode = 'new'
    this.taskBuf.id = ''
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = undefined
    this.taskBuf.name = ''
    this.taskBuf.type = 'single'
    this.taskBuf.status = 'notDone'
    this.taskBuf.totalAmount = 0
    this.taskBuf.currentAmount = 0
    this.taskBuf.colorHex = undefined
    this.taskBuf.hasReminder = false
    this.taskBuf.reminderMs = Date.now()
    this.taskBuf.repeatRule = 'never'
    this.taskBuf.weekdays = []
    this.taskSheetVisible = true
  }

  private openAddChild(parent: TaskItem): void {
    this.taskBuf.mode = 'newChild'
    this.taskBuf.id = ''
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = parent.id
    this.taskBuf.name = ''
    this.taskBuf.type = 'single'
    this.taskBuf.status = 'notDone'
    this.taskBuf.totalAmount = 0
    this.taskBuf.currentAmount = 0
    this.taskBuf.colorHex = undefined
    this.taskBuf.hasReminder = false
    this.taskBuf.reminderMs = Date.now()
    this.taskBuf.repeatRule = 'never'
    this.taskBuf.weekdays = []
    this.taskSheetVisible = true
  }

  private openEditTask(task: TaskItem): void {
    this.taskBuf.mode = 'edit'
    this.taskBuf.id = task.id
    this.taskBuf.goalId = this.selectedGoalId
    this.taskBuf.parentId = task.parentTaskId
    this.taskBuf.name = task.name
    this.taskBuf.type = task.type
    this.taskBuf.status = task.status
    this.taskBuf.totalAmount = task.totalAmount
    this.taskBuf.currentAmount = task.currentAmount
    this.taskBuf.colorHex = task.colorHex
    this.taskBuf.hasReminder = task.reminderDate !== undefined
    this.taskBuf.reminderMs = task.reminderDate !== undefined ? task.reminderDate : Date.now()
    this.taskBuf.repeatRule = task.repeatRule === undefined ? 'never' : task.repeatRule
    this.taskBuf.weekdays = task.effectiveWeekdays()
    this.taskSheetVisible = true
  }

  private async saveTaskEditor(): Promise<void> {
    const buf = this.taskBuf
    const name = buf.name.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: I18n.L('请输入任务名称', 'Enter a task name') })
      return
    }
    const reminderMs = buf.hasReminder ? buf.reminderMs : undefined
    const repeatRule = buf.hasReminder ? buf.repeatRule : undefined
    const weekdays = buf.hasReminder && buf.repeatRule === 'custom' ? buf.weekdays.join(',') : undefined

    if (buf.mode === 'edit') {
      const task = AppViewModel.findInTree(this.currentTree, buf.id)
      if (task !== undefined) {
        task.name = name
        task.type = buf.type
        task.status = buf.status
        task.totalAmount = Math.max(0, buf.totalAmount)
        task.currentAmount = Math.min(Math.max(buf.currentAmount, 0), task.totalAmount)
        task.colorHex = buf.colorHex
        task.reminderDate = reminderMs
        task.repeatRule = repeatRule
        task.customWeekdaysRaw = weekdays
        await AppViewModel.saveTask(task)
        await this.syncReminder(task)
      }
    } else {
      const parentNode = buf.parentId !== undefined ? AppViewModel.findInTree(this.currentTree, buf.parentId) : undefined
      const directChildren: TaskItem[] = buf.parentId !== undefined ? (parentNode !== undefined ? parentNode.subtasks : []) : this.currentTree
      const sortOrder = AppViewModel.nextSortOrderOfDirectChildren(directChildren)
      const t = await AppViewModel.addTask(name, buf.type, this.selectedGoalId, buf.parentId,
        buf.status, Math.max(0, buf.totalAmount), Math.min(Math.max(buf.currentAmount, 0), Math.max(0, buf.totalAmount)),
        reminderMs, repeatRule, weekdays, sortOrder)
      if (buf.parentId !== undefined) {
        this.expanded.add(buf.parentId)
      }
      // 新任务已由 addTask 落库；刷新树使其出现在视图
    }
    this.taskSheetVisible = false
    await this.loadSelectedGoal(this.goals)
    this.revision++
  }

  /** 同步任务提醒（编辑场景）：有提醒 → 重新调度；无提醒 → 取消 */
  private async syncReminder(task: TaskItem): Promise<void> {
    try {
      if (task.reminderDate !== undefined) {
        const gname = await AppViewModel.goalNameOf(this.selectedGoalId)
        await ReminderService.schedule(task, gname)
      } else {
        await ReminderService.cancel(task.id)
      }
    } catch (e) {
      // 忽略提醒调度失败（通知权限被拒等）
    }
  }

  // ===== 目标编辑打开/保存 =====
  private openAddGoal(): void {
    this.goalBuf.isNew = true
    this.goalBuf.id = ''
    this.goalBuf.name = ''
    this.goalBuf.colorHex = 'auto'
    this.goalBuf.countingMode = 'allTasks'
    this.goalSheetVisible = true
  }

  private openEditGoal(g: Goal): void {
    this.goalBuf.isNew = false
    this.goalBuf.id = g.id
    this.goalBuf.name = g.name
    this.goalBuf.colorHex = g.colorHex
    this.goalBuf.countingMode = g.progressCountingMode
    this.goalSheetVisible = true
  }

  private async saveGoalEditor(): Promise<void> {
    const name = this.goalBuf.name.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: I18n.L('请输入目标名称', 'Enter a goal name') })
      return
    }
    if (this.goalBuf.isNew) {
      const g = await AppViewModel.createGoal(name, this.goalBuf.colorHex, undefined, undefined, undefined, false, false, this.goalBuf.countingMode)
      this.goalSheetVisible = false
      await this.refreshGoals()
      this.selectGoal(g.id)
    } else {
      const g = this.goals.find((it: Goal) => it.id === this.goalBuf.id)
      if (g !== undefined) {
        g.name = name
        g.colorHex = this.goalBuf.colorHex
        g.progressCountingMode = this.goalBuf.countingMode
        await AppViewModel.updateGoal(g)
        this.goalSheetVisible = false
        await this.refreshGoals()
      }
    }
    this.revision++
  }

  private confirmDeleteGoal(g: Goal): void {
    AlertDialog.show({
      title: I18n.L('删除目标', 'Delete Goal'),
      message: I18n.L(`删除目标「${g.name}」？其下所有任务将一并删除。`, `Delete "${g.name}" and all its tasks?`),
      primaryButton: {
        value: I18n.L('取消', 'Cancel'),
        action: () => { }
      },
      secondaryButton: {
        value: I18n.L('删除', 'Delete'),
        fontColor: D.colorDanger,
        action: async () => {
          await AppViewModel.deleteGoal(g.id)
          if (this.selectedGoalId === g.id) {
            this.selectedGoalId = ''
          }
          await this.refreshGoals()
          this.revision++
        }
      }
    })
  }

  private confirmDelete(row: TaskRow): void {
    AlertDialog.show({
      title: I18n.L('删除任务', 'Delete Task'),
      message: I18n.L(`删除任务「${row.task.name}」？其所有子任务将一并删除。`, `Delete "${row.task.name}" and all its subtasks?`),
      primaryButton: {
        value: I18n.L('取消', 'Cancel'),
        action: () => { }
      },
      secondaryButton: {
        value: I18n.L('删除', 'Delete'),
        fontColor: D.colorDanger,
        action: async () => {
          const pid = row.task.parentTaskId
          await AppViewModel.deleteTask(row.task.id)
          this.removeFromTree(this.currentTree, row.task.id)
          if (pid !== undefined) {
            // 刷新以免遗留空父容器（若已被删除则忽略）
          }
          await this.loadSelectedGoal(this.goals)
          this.revision++
        }
      }
    })
  }

  private removeFromTree(tree: TaskItem[], id: string): void {
    for (let i = 0; i < tree.length; i++) {
      if (tree[i].id === id) {
        tree.splice(i, 1)
        return
      }
      this.removeFromTree(tree[i].subtasks, id)
    }
  }

  // ===== 主题辅助 =====
  private isDark(): boolean {
    return Theme.dark(this.colorScheme)
  }

  private pal(): ThemePalette {
    return Theme.palette(this.isDark())
  }

  private currentBackground(): string {
    return this.pal().bg
  }

  private currentCard(): string {
    return this.pal().card
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

  private dividerC(): string {
    return this.pal().divider
  }

  private colorPressed(): string {
    return this.isDark() ? '#33FFFFFF' : D.colorPressed
  }

  private resolveColor(hex: string): string {
    if (hex === 'auto' || hex.length === 0) {
      return this.isDark() ? '#B3B3BC' : '#7C7C7C'
    }
    return hex
  }
}