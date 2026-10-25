import SwiftUI

/// 设计 token(见 docs/ios-design.md):暖石墨底 + 琥珀仪表背光 + 语义色。
enum Theme {
    static let bg = Color(hex: 0x0D0C0A)
    static let surface = Color(hex: 0x16140F)
    static let surface2 = Color(hex: 0x1E1B15)
    static let stroke = Color(hex: 0x2C2820)
    static let ink = Color(hex: 0xF4EFE6)
    static let inkDim = Color(hex: 0x9A9184)
    static let inkFaint = Color(hex: 0x6B6459)
    static let amber = Color(hex: 0xF2A33C)
    static let amberBright = Color(hex: 0xFFC164)
    static let electric = Color(hex: 0x5BA6D6)
    static let okGreen = Color(hex: 0x5DB886)
    static let alertRed = Color(hex: 0xE0524B)

    static let cardRadius: CGFloat = 12
    static let tileRadius: CGFloat = 10
    static let pageMargin: CGFloat = 20
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

extension Font {
    /// 读数字体:SF Mono,器械精确感(等效 DIN 1451),零打包成本。
    static func instrument(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// 状态语义色(见 docs/ios-design.md「状态语义」:正常=ok-green,需注意=alert-red,电=electric)。
enum StatusTone {
    case ok, alert, electric, neutral

    var color: Color {
        switch self {
        case .ok: return Theme.okGreen
        case .alert: return Theme.alertRed
        case .electric: return Theme.electric
        case .neutral: return Theme.inkDim
        }
    }
}
