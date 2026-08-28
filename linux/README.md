# Tick · Linux 版（C++17 + Qt 6 Widgets + SQLite）

将 iOS 版 Tick（目标 → 无限层级任务树）忠实移植到 Linux 桌面端。使用
Qt 6 Widgets（QSplitter 主布局 / QTreeWidget 任务树 / QDialog 编辑）、
SQLite（QSqlDatabase）持久化。

## 功能

- **目标管理**：左侧边栏新增 / 编辑 / 删除目标（名称、颜色、图标、起止日期、进度统计模式）
- **无限层级任务**：单项 / 进度两种类型，支持半完成与删除态，任意层级嵌套
- **递归进度引擎**：`allTasks` / `leafTasks` 两种统计模式，删除态整棵子树不计入，
  父任务被子任务接管后由子任务折算，全删后代解除接管并保留手动值（`src/domain/progressengine.*`）
- **继承链**：子任务 → 父任务 → … → 目标 逐级回退颜色 / 日期（`ProgressEngine::effective*`）
- **提醒**：提醒时间 + 重复规则（不重复 / 每天 / 每周 / 每月 / 自定义周几），
  使用 `QSystemTrayIcon::showMessage` 展示（无托盘时回退消息框）
- **AI 助手**：设置页配置 OpenAI 兼容 API（默认 DeepSeek `https://api.deepseek.com/v1` · `deepseek-chat`，
  API Key 存 QSettings），多轮对话（`POST {base}/chat/completions`，`QNetworkAccessManager`），
  附件解析（`.txt/.md` 直接读、`.pdf` 调用系统 `pdftotext`），解析 JSON envelope
  `{"generate":true,"tasks":[…],"message":""}`，`generate=true` 把任务写入当前目标
- **设置**：配色（跟随系统 / 亮 / 暗，用 `QPalette`）、语言（简体中文 / English）、
  AI 配置、JSON 备份导出 / 导入

## 目录结构

```
CMakeLists.txt
src/
  main.cpp
  data/     QSqlDatabase 单例 + Goal/Task/Settings/Chat 仓储（建表 CRUD）
  domain/   ProgressEngine 递归进度引擎
  model/    Goal / TaskItem / enums（与 iOS 对齐）
  services/ AIService、DocumentTextExtractor、NotificationService、JsonBackup
  ui/       MainWindow、GoalDialog、TaskDialog、SettingsDialog、AIChatDialog、theme、translation
resources/  图标（icon.qrc / app_icon.svg）
debian/     打包（control + rules）
redhat/     RPM spec
arch/       PKGBUILD
```

## 构建步骤

前置依赖（Debian/Ubuntu 示例）：

```bash
sudo apt install qt6-base-dev ninja-build cmake libqt6sql6-sqlite
# .pdf 附件解析（可选）：
sudo apt install poppler-utils
```

构建：

```bash
cd linux
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/tick
```

只依赖 `Qt6::Widgets / Qt6::Network / Qt6::Sql`（不依赖 D-Bus），
提醒走系统托盘气泡。

## 打包

- Debian：在 `linux/` 内执行 `dpkg-buildpackage -us -uc`（引用 CMake 产物，安装到 `/usr/bin/tick`）
- RPM：将 `linux/` 打成 `tick-1.0.0.tar.gz` 后 `rpmbuild -tb redhat/tick.spec`
- Arch：在 `linux/` 内执行 `makepkg`（`arch/PKGBUILD` 就地构建 linux 源码树）

## 数据

- SQLite 数据库：`QStandardPaths::AppDataLocation/tick.db`
- 设置（含 API Key）：`QSettings`（`~/.config/Tick/Tick.conf`）