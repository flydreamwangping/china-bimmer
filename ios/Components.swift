import SwiftUI
import UIKit

// MARK: - 环形电量表(身份色:正常 amber,充电中 electric)
struct RingGauge: View {
    let percent: Int
    var color: Color = .amber
    var diameter: CGFloat = 100
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.stroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(percent)")
                    .font(.instrument(30, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text("%")
                    .font(.footnote)
                    .foregroundStyle(Color.inkDim)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - 车辆图片(后端下发 base64 PNG,解码失败回退剪影)
struct VehicleImage: View {
    let base64: String?
    var height: CGFloat = 64

    var body: some View {
        if let ui = decodedImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else {
            placeholder
        }
    }

    private var decodedImage: UIImage? {
        guard let base64 = base64,
              let data = Data(base64Encoded: base64),
              let img = UIImage(data: data) else { return nil }
        return img
    }

    private var placeholder: some View {
        Image(systemName: "car.2.fill")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(Color.inkDim)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

// MARK: - 状态条里的单项(图标 + 文案,正常绿 / 需注意红)
struct StatusItem: View {
    let symbol: String
    let label: String
    var color: Color = .okGreen

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 卡片容器(发丝线分隔,替代阴影)
struct SectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                .strokeBorder(Color.stroke, lineWidth: Layout.hairline)
        )
    }
}

// MARK: - 远程指令 tile(中风险 = amber 描边,一眼可辨)
struct CommandTile: View {
    let command: RemoteCommand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: command.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(command.title)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(Color.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        command.risk == .medium ? .amber : .ink
    }

    private var borderColor: Color {
        command.risk == .medium ? Color.amber.opacity(0.5) : Color.stroke
    }

    private var borderWidth: CGFloat {
        command.risk == .medium ? 1 : Layout.hairline
    }
}

// MARK: - 数值格式化(缺失显示 —)
func fmt(_ v: Double?, digits: Int = 0) -> String {
    guard let v = v else { return "—" }
    return v.formatted(.number.precision(.fractionLength(digits)))
}

// MARK: - 日期格式化(最近更新时间)
func fmtDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MM-dd HH:mm"
    return f.string(from: date)
}
