using Tick.Data;
using Tick.ViewModels;

namespace Tick.Services;

/// <summary>
/// 全局服务定位器：由 App 启动时初始化，各视图 / 对话框据此访问数据库与业务服务。
/// </summary>
public static class AppServices
{
    public static AppDatabase Db = null!;

    public static GoalRepository Goals = null!;

    public static TaskRepository Tasks = null!;

    public static SettingsRepository Settings = null!;

    public static AIService AI = null!;

    public static ToastService Toasts = null!;

    public static AppSettings AppSettings = null!;

    public static MainViewModel Main = null!;

    public static void Initialize()
    {
        Db = new AppDatabase();
        Goals = new GoalRepository(Db.Connection);
        Tasks = new TaskRepository(Db.Connection);
        Settings = new SettingsRepository(Db.Connection);
        AppSettings = AppSettings.Load(Settings);
        AI = new AIService();
        Toasts = new ToastService();
        Main = new MainViewModel(Goals, Tasks);
        Main.Reload();
    }
}