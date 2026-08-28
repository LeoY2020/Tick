using System;
using System.IO;

namespace Tick.Services;

/// <summary>
/// 极简崩溃日志：把致命错误写入 %LOCALAPPDATA%\Tick\tick.log，便于在无控制台的
/// 「解包运行」场景下排查「双击没反应 / 闪退」。
/// </summary>
public static class CrashLog
{
    private static readonly string LogFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Tick", "tick.log");

    public static void Record(string source, Exception? ex) => Record(source, ex?.ToString());

    public static void Record(string source, string? detail)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(LogFile)!);
            File.AppendAllText(LogFile,
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [{source}] {detail}{Environment.NewLine}");
        }
        catch
        {
            // 日志失败也不能再次抛出，否则雪上加霜。
        }
    }
}