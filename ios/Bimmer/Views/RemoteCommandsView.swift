import SwiftUI

/// 远程控制面板(见 docs/ios-design.md「控制面板」):9 项指令,中风险项 amber 描边 + 二次确认。
struct RemoteCommandsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmCommand: RemoteCommand?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("远程控制")
                    .font(.title2)
                    .bold()
                    .foregroundColor(Theme.ink)

                if let notice = model.notice {
                    NoticeBanner(text: notice)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(RemoteCommand.allCases) { cmd in
                        commandTile(cmd)
                    }
                }
            }
            .padding(Theme.pageMargin)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $confirmCommand) { cmd in
            confirmSheet(cmd)
        }
    }

    private func commandTile(_ cmd: RemoteCommand) -> some View {
        Button {
            if cmd.needsConfirm {
                confirmCommand = cmd
            } else {
                run(cmd)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: cmd.icon)
                    .font(.title2)
                    .foregroundColor(cmd.needsConfirm ? Theme.amber : Theme.inkDim)
                Text(cmd.title)
                    .font(.subheadline)
                    .foregroundColor(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.surface2)
            .cornerRadius(Theme.tileRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.tileRadius)
                    .strokeBorder(cmd.needsConfirm ? Theme.amber : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func confirmSheet(_ cmd: RemoteCommand) -> some View {
        VStack(spacing: 16) {
            Image(systemName: cmd.icon)
                .font(.largeTitle)
                .foregroundColor(Theme.amber)
            Text("确认\(cmd.title)?")
                .font(.title3)
                .bold()
                .foregroundColor(Theme.ink)
            Text(cmd.confirmDetail)
                .font(.subheadline)
                .foregroundColor(Theme.alertRed)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("取消") { confirmCommand = nil }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.tileRadius)
                    .foregroundColor(Theme.ink)

                Button {
                    confirmCommand = nil
                    run(cmd)
                } label: {
                    Text(cmd.title)
                        .bold()
                        .foregroundColor(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.amber)
                        .cornerRadius(Theme.tileRadius)
                }
            }
        }
        .padding(20)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
    }

    private func run(_ cmd: RemoteCommand) {
        Task { await model.trigger(cmd) }
    }
}
