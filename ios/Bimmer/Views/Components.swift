import SwiftUI

/// 通用 UI 组件(对应 docs/ios-design.md 的卡片容器 / 状态条 / 环形电量表 / 指令 tile)。

extension View {
    /// 卡片:surface 底 + 12 圆角 + 1pt 发丝线描边(设计文档「不用阴影」)。
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(Theme.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }
}

/// 顶部通知(指令结果回填):成功绿 / 失败红 / 执行中琥珀。
struct NoticeBanner: View {
    let text: String

    private var tone: Color {
        if text.contains("失败") || text.contains("超时") || text.contains("错误") { return Theme.alertRed }
        if text.contains("已执行") || text.contains("成功") { return Theme.okGreen }
        return Theme.amber
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(tone).frame(width: 6, height: 6)
            Text(text).font(.footnote).foregroundColor(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(Theme.tileRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.tileRadius)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

/// 状态条里的单项:图标 + 短标签,按语义色着色。
struct StatusChip: View {
    let icon: String
    let label: String
    let tone: StatusTone

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tone.color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.inkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 剩余电量环形表:正常 amber,充电中 electric(设计文档「环形电量表」)。
struct BatteryRing: View {
    let percent: Double
    let isCharging: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.stroke, lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, percent / 100)))
                .stroke(isCharging ? Theme.electric : Theme.amber,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(percent.rounded()))%")
                    .font(.instrument(size: 18, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Text("剩余电量")
                    .font(.caption2)
                    .foregroundColor(Theme.inkFaint)
            }
        }
        .frame(width: 96, height: 96)
    }
}

/// hero 左侧的大读数(总里程 / 总续航)。
struct HeroStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.instrument(size: 22, weight: .semibold))
                .foregroundColor(Theme.ink)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.inkFaint)
        }
    }
}

/// 迷你统计格(hero 底部「电量/油量/纯电/燃油」、本月数据)。
struct MiniStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.inkFaint)
            Text(value)
                .font(.instrument(size: 13, weight: .medium))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 整行统计(label 左,值右)。
struct StatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label).foregroundColor(Theme.inkFaint)
            Spacer()
            Text(value)
                .font(.instrument(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
