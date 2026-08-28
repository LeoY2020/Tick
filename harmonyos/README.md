# Tick · HarmonyOS（ArkTS + ArkUI）

Tick 待办应用的 HarmonyOS 原生版本，架构对齐 `ios/` 版（目标 → 无限层级任务 → 递归进度 → 提醒 → AI）。

设计语言：HarmonyOS Design（主色 `#0A59F7`、卡片式圆角 16–24、4px 间距网格）。

## 功能

- **目标管理**：抽屉侧边栏切换 / 新建 / 编辑 / 删除目标；各目标数据完全隔离。
- **任务系统**：单项 / 进度两类；无限层级嵌套（List + 缩进 + 展开/折叠）；颜色 / 图标 / 日期沿父链继承到 Goal。
- **递归进度引擎**：`allTasks` / `leafTasks` 两种统计模式；`isDeleted` 删除态整棵子树不计入；接管机制（有子任务时由直接子任务折算、全部子任务删除后自动解除并保留手动值）。
- **提醒**：`@ohos.reminderAgentManager`（日历提醒）+ `@ohos.notificationManager` 权限请求；重复规则：不重复 / 每天 / 每周 / 每月 / 自定义周几。
- **AI 助手**：小艺（盘古）需华为开发者资质，未接入；默认走 OpenAI 兼容 API（Base URL `https://api.deepseek.com/v1`、模型 `deepseek-chat`）。多轮对话 + JSON envelope 解析 + 附件解析（`.txt/.md` 直接读，`.pdf` 给出友好提示）。
- **多语言**：简体中文 / English；**配色**：跟随系统 / 亮 / 暗。
- **备份**：JSON 导出/导入到系统 Download 目录。

## 目录结构

```
harmonyos/
├─ AppScope/                     # 应用级配置（bundle 名、图标、名称）
├─ entry/
│  ├─ src/main/
│  │  ├─ ets/
│  │  │  ├─ entryability/EntryAbility.ets   # 入口：初始化 RDB/偏好 → 加载主页
│  │  │  ├─ pages/Index.ets                # 主界面（目标切换/倒计时/进度/任务树/编辑弹窗）
│  │  │  ├─ pages/Settings.ets             # 设置（配色/语言/AI 配置/JSON 备份）
│  │  │  ├─ pages/AIChat.ets               # AI 对话 + 附件 + 生成任务
│  │  │  ├─ viewmodel/AppViewModel.ets     # 数据协调 / 树扁平化 / 进度封装
│  │  │  ├─ model/                         # Goal / TaskItem / 枚举 / 设置 / Chat 模型 / i18n
│  │  │  ├─ data/                          # RDB 建表(Database) + 各类 DAO(Repositories)
│  │  │  ├─ domain/ProgressEngine.ets      # 递归进度引擎（继承/接管/折算/统计）
│  │  │  ├─ services/                      # AI / 文档解析 / 提醒 / 倒计时 / 备份
│  │  │  └─ theme/DesignTokens.ets         # 设计令牌 + 深浅色主题
│  │  ├─ resources/base/                   # string/color/main_pages 等
│  │  └─ module.json5                      # 模块 + 权限（INTERNET / 提醒）
│  ├─ build-profile.json5
│  ├─ hvigorfile.ts
│  └─ oh-package.json5
├─ build-profile.json5
├─ hvigor/hvigor-config.json5
├─ oh-package.json5
└─ README.md
```

## 用 DevEco Studio 打开构建

1. 安装 **DevEco Studio 5.0.0** 或更高版本（含 HarmonyOS SDK，`compatibleSdkVersion: 5.0.0(12)` 或更高）。
2. `File → Open` 打开本目录 `harmonyos/`（工程根）。
3. 等待依赖同步完成（`oh-package.json5` 无第三方运行依赖）。
4. 连接真机或模拟器（HarmonyOS 设备），`Run` 运行 `entry` 模块。
   - 未配置签名时，先在 `Project Structure → Signing Configs` 完成自动签名（需华为开发者账号）。
5. 构建产物：`entry/build/default/outputs/default/entry-default-signed.hap`。

## 权限

`entry/src/main/module.json5` 声明：

- `ohos.permission.PUBLISH_AGENT_REMINDER`：发送定时/重复任务提醒。
- `ohos.permission.INTERNET`：AI 对话与生成、数据备份导出/导入。

## AI 配置与附注

- 小艺（盘古）无公开第三方大模型 API，需华为开发者资质及其移动服务授权才可内嵌；`services/AIService.ets` 的 `HuaweiAssistant` 已预留接入点，未授权时自动回退到用户自配的 OpenAI 兼容 API。
- 系统提示词强制要求模型输出 JSON envelope，且「严禁生成『了解 xxx / 阅读附件 / 整理要点』类空泛任务」。
- envelope 解析：`{"generate":true,"tasks":[{"name":"","children":[]}],"message":""}` → 任务写入当前选中目标（不展示），`message` 展示；`{"generate":false,"message":""}` → 仅展示 message。

## 数据

- 本地持久化：`@ohos.data.relationalStore`（RDB），表 `goal / task / ai_chat_session / settings`。
- 偏好存储：`@ohos.data.preferences`（`tick_settings`），与 `settings` 表镜像。
- JSON 备份：`services/BackupService.ets`（导出/导入到 Download）。

## 说明

由于本目录不含 HarmonyOS SDK，需在 DevEco Studio 中构建与测试；本仓库只承载源码与配置。