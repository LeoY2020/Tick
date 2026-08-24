import SwiftUI
import UIKit

/// HEX 颜色工具
enum HexColor {
    /// 自动颜色标识：深色模式解析为白色、浅色模式解析为黑色
    static let autoHex = "auto"

    /// 预设色板（12 色）
    static let palette: [(name: String, hex: String)] = [
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
    ]

    /// 解析为最终颜色："auto" 按色彩方案适配（深色白 / 浅色黑），其余按 HEX 解析
    static func resolvedColor(from hex: String, colorScheme: ColorScheme) -> Color {
        if hex.caseInsensitiveCompare(autoHex) == .orderedSame {
            return colorScheme == .dark ? .white : .black
        }
        return color(from: hex)
    }

    /// 解析 HEX 字符串为 Color：支持 "#RRGGBB"、"RRGGBB" 与 3 位缩写（如 "F00"），无效返回黑色
    static func color(from hex: String) -> Color {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        // 3 位缩写扩展为 6 位
        if value.count == 3 {
            value = value.map { String($0) + String($0) }.joined()
        }

        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            return .black
        }
        return Color(red: Double((rgb >> 16) & 0xFF) / 255.0,
                     green: Double((rgb >> 8) & 0xFF) / 255.0,
                     blue: Double(rgb & 0xFF) / 255.0)
    }

    /// Color 转 "#RRGGBB" 字符串（经 UIColor 提取 RGB 分量）
    static func hex(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }
}

/// 颜色圆点：HEX 为 "auto" 时按系统外观自适应（深色白 / 浅色黑），其余按 HEX 解析
struct AdaptiveColorDot: View {
    let hex: String
    var diameter: CGFloat = 12

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(HexColor.resolvedColor(from: hex, colorScheme: colorScheme))
            .frame(width: diameter, height: diameter)
    }
}
