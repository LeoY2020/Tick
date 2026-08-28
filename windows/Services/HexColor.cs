using System.Globalization;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace Tick.Services;

/// <summary>HEX 颜色工具（WinUI 3 版本）</summary>
public static class HexColor
{
    /// <summary>自动颜色标识：深色模式解析为白色、浅色模式解析为黑色</summary>
    public const string AutoHex = "auto";

    /// <summary>预设色板（12 色）</summary>
    public static readonly (string Name, string Hex)[] Palette =
    {
        ("黑色", "#000000"),
        ("红色", "#FF3B30"),
        ("橙色", "#FF9500"),
        ("黄色", "#FFCC00"),
        ("绿色", "#34C759"),
        ("薄荷绿", "#00C7BE"),
        ("青色", "#30B0C7"),
        ("蓝色", "#007AFF"),
        ("靛蓝", "#5856D6"),
        ("紫色", "#AF52DE"),
        ("粉色", "#FF2D55"),
        ("棕色", "#A2845E"),
    };

    /// <summary>解析为最终颜色："auto" 按色彩方案适配（深色白 / 浅色黑），其余按 HEX 解析</summary>
    public static Color Resolve(string hex, bool isDark)
    {
        if (string.Equals(hex, AutoHex, StringComparison.OrdinalIgnoreCase))
            return isDark ? Colors.White : Colors.Black;
        return Parse(hex);
    }

    /// <summary>解析 HEX 字符串为 Color：支持 "#RRGGBB"、"RRGGBB" 与 3 位缩写，无效返回黑色</summary>
    public static Color Parse(string? hex)
    {
        var value = (hex ?? "").Trim();
        if (value.StartsWith('#'))
            value = value.Substring(1);

        if (value.Length == 3)
            value = $"{value[0]}{value[0]}{value[1]}{value[1]}{value[2]}{value[2]}";

        if (value.Length != 6 || !uint.TryParse(value, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var rgb))
            return Colors.Black;

        return Color.FromArgb(
            255,
            (byte)((rgb >> 16) & 0xFF),
            (byte)((rgb >> 8) & 0xFF),
            (byte)(rgb & 0xFF));
    }

    public static SolidColorBrush Brush(string hex, bool isDark) => new(Resolve(hex, isDark));
}