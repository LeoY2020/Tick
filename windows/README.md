# Tick · Windows 版

C# / WinUI 3（Fluent Design）+ SQLite 实现的跨平台待办应用 Windows 版本，功能与 iOS 版对齐：

- 目标（Goal）管理：配色方案（ColorOS/OneUI 等 8 套皮肤由全局主题承载在本平台统一为 Fluent 强调色）、名称、颜色、图标、起止日期、倒计时
- 无限层级任务树（TaskItem）：单项 / 进度两类，支持半完成、删除态
- 递归进度引擎：全任务 / 仅叶子任务两种统计模式，任务接管机制（有子任务后状态/进度只读、由子任务折算；子任务全删解除接管并保留手动值）
- 本地通知与重复提醒（每日 / 每周 / 每月 / 自定义周几）
- AI 多轮对话 + 附件解析（.txt / .md / .pdf）+ 任务树一键写入当前目标
- 配色（跟随系统 / 亮 / 暗）、语言（简体中文 / English）、JSON 导出 / 导入备份

## AI 策略

Windows Copilot 无第三方公开 API，应用不内嵌 AI：设置页提供「Copilot 入口」说明，
实际调用走用户配置的 OpenAI 兼容 API（默认 `https://api.deepseek.com/v1` + `deepseek-chat`），
API Key 使用 Windows DPAPI 加密存储。

## 环境要求

- Windows 10 1809（Build 17763）+ 或 Windows 11
- Visual Studio 2022（含「Windows 应用 SDK / WinUI 3」工作负载）或 .NET 8 SDK

## 构建与运行

```powershell
# 方式一：Visual Studio 直接打开 Tick.sln 构建运行

# 方式二：命令行
dotnet build Tick.sln -c Debug
# 解包运行（非 MSIX，无需证书）：
dotnet run --project Tick.csproj
```

> 当前工程采用 `WindowsPackageType=None`（解包运行，免 MSIX 签名）。
> 如需生成 MSIX 安装包，将 `Tick.csproj` 中 `WindowsPackageType` 改为 `MSIX`，
> 并配置 `Package.appxmanifest` 与签名证书。

## 目录结构

| 目录 | 说明 |
|---|---|
| `Models/` | Goal / TaskItem / 枚举 / 聊天模型 |
| `Data/` | SQLite（Microsoft.Data.Sqlite）建库与仓储 |
| `Domain/` | 递归进度引擎（与 iOS 版同名算法忠实移植） |
| `Services/` | AI 服务、文档解析、备份、通知、本地化、Copilot 入口 |
| `ViewModels/` | MVVM 视图模型 |
| `Views/` | MainWindow + 对话框 |