import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 600)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $viewModel.selectedServerID) {
            Section("General") {
                HStack {
                    Text("Local server port")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Disabled", text: $viewModel.localServerPort)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .disabled(viewModel.isLocked)
                }
            }

            Section("Servers") {
                ForEach(viewModel.servers) { server in
                    Label(
                        server.url.isEmpty ? "New Server" : server.url
                            .replacingOccurrences(of: "https://", with: "")
                            .replacingOccurrences(of: "http://", with: ""),
                        systemImage: "server.rack"
                    )
                    .foregroundStyle(.secondary)
                    .tag(server.id)
                }
                .onDelete { indexSet in
                    guard !viewModel.isLocked else { return }
                    for index in indexSet {
                        viewModel.removeServer(viewModel.servers[index])
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    viewModel.isLocked.toggle()
                } label: {
                    Image(systemName: viewModel.isLocked ? "lock.fill" : "lock.open.fill")
                }
                .buttonStyle(.borderless)
                .help(viewModel.isLocked ? "Unlock to edit" : "Lock editing")

                Divider()
                    .frame(height: 16)

                Button(action: viewModel.addServer) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLocked)

                if let selectedID = viewModel.selectedServerID,
                   let server = viewModel.servers.first(where: { $0.id == selectedID }) {
                    Button(action: { viewModel.removeServer(server) }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isLocked)
                }

                Spacer()

                if viewModel.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                }
            }
            .padding(8)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let index = viewModel.selectedServerIndex() {
            ServerDetailView(
                server: $viewModel.servers[index],
                viewModel: viewModel
            )
            .id(viewModel.servers[index].id)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a server or add one")
                    .foregroundStyle(.secondary)
                Button("Add Server") {
                    viewModel.isLocked = false
                    viewModel.addServer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
