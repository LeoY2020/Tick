using System.Globalization;
using Microsoft.UI;
using Microsoft.UI.Xaml.Media;

namespace Tick.Services;

/// <summary>HEX 颜色工具（WinUI 3 版本）</summary>
public static class HexColor
{
    /// <summary>自动颜色标识：深色模式解析为白色、浅色模式解析为黑色</summary>
    public const string AutoHex = "auto";

    /// <summary>预设色板（12 色；Name 为本地化键，由调用方经 <see cref="Localization.Tr"/> 解析）</summary>
    public static readonly (string Key, string Hex)[] Palette =
    {
        ("color.black", "#000000"),
        ("color.red", "#FF3B30"),
        ("color.orange", "#FF9500"),
        ("color.yellow", "#FFCC00"),
        ("color.green", "#34C759"),
        ("color.mint", "#00C7BE"),
        ("color.teal", "#30B0C7"),
        ("color.blue", "#007AFF"),
        ("color.indigo", "#5856D6"),
        ("color.purple", "#AF52DE"),
        ("color.pink", "#FF2D55"),
        ("color.brown", "#A2845E"),
    };

    /// <summary>解析为最终颜色："auto" 按色彩方案适配（深色白 / 浅色黑），其余按 HEX 解析</summary>
    public static Windows.UI.Color Resolve(string hex, bool isDark)
    {
        if (string.Equals(hex, AutoHex, StringComparison.OrdinalIgnoreCase))
            return isDark ? Colors.White : Colors.Black;
        return Parse(hex);
    }

    /// <summary>解析 HEX 字符串为 Color：支持 "#RRGGBB"、"RRGGBB" 与 3 位缩写，无效返回黑色</summary>
    public static Windows.UI.Color Parse(string? hex)
    {
        var value = (hex ?? "").Trim();
        if (value.StartsWith('#'))
            value = value.Substring(1);

        if (value.Length == 3)
            value = $"{value[0]}{value[0]}{value[1]}{value[1]}{value[2]}{value[2]}";

        if (value.Length != 6 || !uint.TryParse(value, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var rgb))
            return Colors.Black;

        return Windows.UI.Color.FromArgb(
            255,
            (byte)((rgb >> 16) & 0xFF),
            (byte)((rgb >> 8) & 0xFF),
            (byte)(rgb & 0xFF));
    }

    public static SolidColorBrush Brush(string hex, bool isDark) => new(Resolve(hex, isDark));
}