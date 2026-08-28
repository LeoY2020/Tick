using System.Text;
using Microsoft.UI.Xaml;
using Tick.Services;

namespace Tick;

public partial class App : Application
{
    /// <summary>当前主窗口引用（供主题 / 语言刷新）</summary>
    public static Views.MainWindow MainWindow { get; private set; } = null!;

    public App()
    {
        InitializeComponent();
        // 注册 GB18030 / GBK 编码，供按 GBK 解码中文 .txt 附件
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        AppServices.Initialize();
        Localization.SetLanguage(AppServices.AppSettings.Language);

        MainWindow = new Views.MainWindow();
        MainWindow.ApplyTheme(AppServices.AppSettings.ColorScheme);
        MainWindow.Activate();
    }
}