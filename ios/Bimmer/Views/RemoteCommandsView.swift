import SwiftUI

struct RemoteCommandsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmCommand: RemoteCommand?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("远程控制").font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RemoteCommand.allCases) { cmd in
                    Button {
                        if cmd.needsConfirm {
                            confirmCommand = cmd
                        } else {
                            run(cmd)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cmd.icon).font(.title2)
                            Text(cmd.title).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert(item: $confirmCommand) { cmd in
            Alert(
                title: Text("确认\(cmd.title)?"),
                message: Text(cmd.confirmDetail),
                primaryButton: .destructive(Text(cmd.title)) { run(cmd) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func run(_ cmd: RemoteCommand) {
        Task { await model.trigger(cmd) }
    }
}
