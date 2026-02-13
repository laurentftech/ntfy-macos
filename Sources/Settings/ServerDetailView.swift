import SwiftUI

// MARK: - TextField Style Modifier

struct LockedTextFieldModifier: ViewModifier {
    let isLocked: Bool
    
    func body(content: Content) -> some View {
        if isLocked {
            content.textFieldStyle(.plain)
        } else {
            content.textFieldStyle(.roundedBorder)
        }
    }
}

struct ServerDetailView: View {
    @Binding var server: EditableServer
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showTokenSheet = false

    private var isLocked: Bool { viewModel.isLocked }

    var body: some View {
        Form {
            Section("Server") {
                HStack {
                    Text("URL")
                        .foregroundStyle(.secondary)
                    TextField("", text: $server.url)
                        .modifier(LockedTextFieldModifier(isLocked: isLocked))
                        .disabled(isLocked)
                }

                HStack {
                    if server.token.isEmpty {
                        Text("Token: not configured")
                            .foregroundStyle(.secondary)
                    } else if server.storeInKeychain {
                        Label("Token stored in Keychain", systemImage: "key.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Token stored in config file", systemImage: "doc.text")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Manage...") {
                        showTokenSheet = true
                    }
                    .disabled(isLocked)
                }

                Toggle("Fetch missed messages on reconnect", isOn: $server.fetchMissed)
                    .foregroundStyle(.secondary)
                    .disabled(isLocked)
            }

            Section {
                ForEach($server.topics) { $topic in
                    TopicRowView(topic: $topic, isLocked: isLocked) {
                        server.topics.removeAll { $0.id == topic.id }
                    }
                }

                if !isLocked {
                    Button {
                        viewModel.addTopic(to: server.id)
                    } label: {
                        Label("Add Topic", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                HStack {
                    Text("Topics")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Fetch")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showTokenSheet) {
            TokenSheetView(server: $server)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if let error = viewModel.saveError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(1)
                }

                Spacer()

                if !viewModel.isLocked {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])

                    Button("Save") {
                        viewModel.save()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!viewModel.hasUnsavedChanges)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
        }
        .background(.bar)
    }
}

// MARK: - Token Management Sheet

struct TokenSheetView: View {
    @Binding var server: EditableServer
    @Environment(\.dismiss) private var dismiss

    @State private var tokenText: String = ""
    @State private var storageChoice: TokenStorage = .keychain

    enum TokenStorage: String, CaseIterable {
        case keychain = "Keychain (recommended)"
        case configFile = "Config file"
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if !server.token.isEmpty {
                        HStack {
                            Label(
                                server.storeInKeychain ? "Currently in Keychain" : "Currently in config file",
                                systemImage: server.storeInKeychain ? "key.fill" : "doc.text"
                            )
                            Spacer()
                            Button {
                                server.token = ""
                                server.storeInKeychain = false
                                dismiss()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove token")
                        }
                    }
                } header: {
                    Text("Current Status")
                }

                Section {
                    SecureField("Enter token", text: $tokenText)

                    Picker("Store in", selection: $storageChoice) {
                        ForEach(TokenStorage.allCases, id: \.self) { storage in
                            Text(storage.rawValue).tag(storage)
                        }
                    }
                } header: {
                    Text(server.token.isEmpty ? "Add Token" : "Replace Token")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save Token") {
                    server.token = tokenText
                    server.storeInKeychain = (storageChoice == .keychain)
                    dismiss()
                }
                .disabled(tokenText.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
        }
        .frame(width: 420, height: 280)
        .onAppear {
            storageChoice = server.storeInKeychain ? .keychain : .configFile
        }
    }
}
