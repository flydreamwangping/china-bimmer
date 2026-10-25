import SwiftUI

// MARK: - 颜色 Token(暖石墨底 + 琥珀身份色 + 语义色)
// 见 docs/ios-design.md「设计 Token」。
extension Color {
    // 背景
    static let bg         = Color(hex: 0x0D0C0A)
    static let surface    = Color(hex: 0x16140F)
    static let surface2   = Color(hex: 0x1E1B15)
    static let stroke     = Color(hex: 0x2C2820)

    // 文字(暖白)
    static let ink        = Color(hex: 0xF4EFE6)
    static let inkDim     = Color(hex: 0x9A9184)
    static let inkFaint   = Color(hex: 0x6B6459)

    // 身份色
    static let amber       = Color(hex: 0xF2A33C)
    static let amberBright = Color(hex: 0xFFC164)

    // 语义色
    static let electric    = Color(hex: 0x5BA6D6) // 电
    static let okGreen     = Color(hex: 0x5DB886) // 安全
    static let alertRed    = Color(hex: 0xE0524B) // 需注意
}

extension Color {
    /// 用十六进制字面量构造颜色(0xRRGGBB)。
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 字体(器械读数 = 等宽数字,仿 DIN 1451)
extension Font {
    static func instrument(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - 间距 / 圆角
enum Layout {
    static let gutter: CGFloat = 20      // 页面左右边距
    static let cardRadius: CGFloat = 12  // 卡片圆角
    static let tileRadius: CGFloat = 10  // tile 圆角
    static let hairline: CGFloat = 1     // 发丝分隔线
}
