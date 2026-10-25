import SwiftUI

/// 远程控制面板:中风险指令二次确认,其余直接执行。
struct ControlPanelView: View {
    @State private var pending: RemoteCommand?   // 待二次确认的中风险指令
    @State private var running: RemoteCommand?   // 执行中的指令
    @State private var notice: String?           // 结果通知(底部浮动)

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(RemoteCommand.allCases) { cmd in
                        CommandTile(command: cmd) { tap(cmd) }
                    }
                }
                .padding(Layout.gutter)
            }
            .background(Color.bg)
            .navigationTitle("远程控制")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) { noticeBanner }
        }
        .overlay { confirmOverlay }
    }

    private var noticeBanner: some View {
        Group {
            if let notice {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(Color.bg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.ink)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut, value: notice)
    }

    private var confirmOverlay: some View {
        Group {
            if let cmd = pending {
                ConfirmOverlay(command: cmd) {
                    run(cmd)
                    pending = nil
                } onDismiss: {
                    pending = nil
                }
            }
        }
    }

    private func tap(_ cmd: RemoteCommand) {
        if cmd.risk == .medium {
            pending = cmd
        } else {
            run(cmd)
        }
    }

    /// 实际发送指令处:接入后端后替换为真实 API 调用(对应 app.py 的 `_trigger`)。
    private func run(_ cmd: RemoteCommand) {
        running = cmd
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 模拟网络往返
            notice = "\(cmd.title):已执行"
            running = nil
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            notice = nil
        }
    }
}

/// 中风险指令的二次确认:底部弹出卡片(自定义 overlay,iOS 15 兼容)。
struct ConfirmOverlay: View {
    let command: RemoteCommand
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: command.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.amber)

                    Text("确认\(command.title)?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink)

                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(Color.alertRed)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        Button {
                            onConfirm()
                        } label: {
                            Text("确认\(command.title)")
                                .font(.headline)
                                .foregroundStyle(Color.bg)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.amber)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button("取消") { onDismiss() }
                            .foregroundStyle(Color.inkDim)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private var warning: String {
        switch command {
        case .unlock: return "将真实解锁车辆,请注意周围安全。"
        case .climateOn: return "将远程开启空调,约 15 分钟后自动停止。"
        case .chargeStart: return "将远程开始充电。"
        default: return "指令将真实作用于车辆。"
        }
    }
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ControlPanelView()
    }
}
