import Foundation
import Combine

struct EditableServer: Identifiable {
    let id: UUID
    var url: String
    var token: String
    var storeInKeychain: Bool
    var fetchMissed: Bool
    var topics: [EditableTopic]

    // Track original URL for Keychain cleanup on rename
    var originalUrl: String?

    init(id: UUID = UUID(), url: String = "", token: String = "", storeInKeychain: Bool = false, fetchMissed: Bool = false, topics: [EditableTopic] = [], originalUrl: String? = nil) {
        self.id = id
        self.url = url
        self.token = token
        self.storeInKeychain = storeInKeychain
        self.fetchMissed = fetchMissed
        self.topics = topics
        self.originalUrl = originalUrl
    }
}

struct EditableTopic: Identifiable {
    let id: UUID
    var name: String
    var fetchMissed: Bool?

    // Phase 2 fields (preserved during round-trip but not editable yet)
    var iconPath: String?
    var iconSymbol: String?
    var autoRunScript: String?
    var silent: Bool?
    var clickUrl: ClickUrlConfig?
    var actions: [NotificationAction]?

    init(id: UUID = UUID(), name: String = "", fetchMissed: Bool? = nil, iconPath: String? = nil, iconSymbol: String? = nil, autoRunScript: String? = nil, silent: Bool? = nil, clickUrl: ClickUrlConfig? = nil, actions: [NotificationAction]? = nil) {
        self.id = id
        self.name = name
        self.fetchMissed = fetchMissed
        self.iconPath = iconPath
        self.iconSymbol = iconSymbol
        self.autoRunScript = autoRunScript
        self.silent = silent
        self.clickUrl = clickUrl
        self.actions = actions
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var servers: [EditableServer] = []
    @Published var localServerPort: String = ""
    @Published var selectedServerID: UUID?
    @Published var hasUnsavedChanges: Bool = false
    @Published var isLocked: Bool = true
    @Published var saveError: String?
    @Published var serverConnectionStates: [String: StatusBarController.ConnectionState] = [:]

    func refreshConnectionStates() {
        let statuses = StatusBarController.shared.getServerStatuses()
        var states: [String: StatusBarController.ConnectionState] = [:]
        for (url, status) in statuses {
            states[url] = status.state
        }
        serverConnectionStates = states
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Track changes to mark unsaved state
        $servers
            .dropFirst()
            .sink { [weak self] _ in self?.hasUnsavedChanges = true }
            .store(in: &cancellables)
        $localServerPort
            .dropFirst()
            .sink { [weak self] _ in self?.hasUnsavedChanges = true }
            .store(in: &cancellables)
    }

    func loadFromConfig() {
        let config = ConfigManager.shared.config

        if let port = config?.localServerPort {
            localServerPort = String(port)
        } else {
            localServerPort = ""
        }

        servers = (config?.servers ?? []).map { server in
            // Check if token is stored in Keychain
            let keychainToken = try? KeychainHelper.getToken(forServer: server.url)
            let hasKeychainToken = keychainToken != nil
            let tokenValue = keychainToken ?? server.token ?? ""

            return EditableServer(
                url: server.url,
                token: tokenValue,
                storeInKeychain: hasKeychainToken,
                fetchMissed: server.fetchMissed ?? false,
                topics: server.topics.map { topic in
                    EditableTopic(
                        name: topic.name,
                        fetchMissed: topic.fetchMissed,
                        iconPath: topic.iconPath,
                        iconSymbol: topic.iconSymbol,
                        autoRunScript: topic.autoRunScript,
                        silent: topic.silent,
                        clickUrl: topic.clickUrl,
                        actions: topic.actions
                    )
                },
                originalUrl: server.url
            )
        }

        // Auto-select first server
        selectedServerID = servers.first?.id

        hasUnsavedChanges = false
        saveError = nil
    }

    func save() {
        saveError = nil

        // Validation
        for server in servers {
            if server.url.trimmingCharacters(in: .whitespaces).isEmpty {
                saveError = "Server URL cannot be empty"
                return
            }
            for topic in server.topics {
                if topic.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveError = "Topic name cannot be empty"
                    return
                }
            }
            // Check for duplicate topic names within a server
            let topicNames = server.topics.map { $0.name }
            if Set(topicNames).count != topicNames.count {
                saveError = "Duplicate topic names in server \(server.url)"
                return
            }
        }

        // Parse port
        let port: UInt16?
        if localServerPort.trimmingCharacters(in: .whitespaces).isEmpty {
            port = nil
        } else if let p = UInt16(localServerPort) {
            port = p
        } else {
            saveError = "Invalid port number"
            return
        }

        // Build AppConfig
        let serverConfigs = servers.map { server in
            let topicConfigs = server.topics.map { topic in
                TopicConfig(
                    name: topic.name,
                    iconPath: topic.iconPath,
                    iconSymbol: topic.iconSymbol,
                    autoRunScript: topic.autoRunScript,
                    silent: topic.silent,
                    clickUrl: topic.clickUrl,
                    actions: topic.actions,
                    fetchMissed: topic.fetchMissed
                )
            }

            // If storing in Keychain, don't write token to YAML
            let yamlToken: String? = server.storeInKeychain ? nil : (server.token.isEmpty ? nil : server.token)

            return ServerConfig(
                url: server.url,
                token: yamlToken,
                topics: topicConfigs,
                fetchMissed: server.fetchMissed ? true : nil
            )
        }

        let appConfig = AppConfig(servers: serverConfigs, localServerPort: port)

        // Handle Keychain operations
        for server in servers {
            let token = server.token.trimmingCharacters(in: .whitespaces)

            if server.storeInKeychain && !token.isEmpty {
                try? KeychainHelper.saveToken(token, forServer: server.url)

                // If URL changed, clean up old Keychain entry
                if let oldUrl = server.originalUrl, oldUrl != server.url {
                    try? KeychainHelper.deleteToken(forServer: oldUrl)
                }
            } else if !server.storeInKeychain {
                // Remove from Keychain if user unchecked the option
                if let oldUrl = server.originalUrl {
                    try? KeychainHelper.deleteToken(forServer: oldUrl)
                }
                try? KeychainHelper.deleteToken(forServer: server.url)
            }
        }

        // Write YAML
        do {
            try ConfigManager.saveConfig(appConfig)
            hasUnsavedChanges = false

            // Update originalUrl for all servers after successful save
            for i in servers.indices {
                servers[i].originalUrl = servers[i].url
            }
            // Reset unsaved flag (the assignment above triggers Combine)
            hasUnsavedChanges = false
            isLocked = true
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }

    func cancel() {
        loadFromConfig()
        isLocked = true
    }

    // MARK: - Server CRUD

    func addServer() {
        let server = EditableServer(
            url: "https://",
            topics: [EditableTopic(name: "")]
        )
        servers.append(server)
        selectedServerID = server.id
    }

    func removeServer(_ server: EditableServer) {
        servers.removeAll { $0.id == server.id }
        if selectedServerID == server.id {
            selectedServerID = servers.first?.id
        }
    }

    // MARK: - Topic CRUD

    func addTopic(to serverID: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else { return }
        servers[index].topics.append(EditableTopic(name: ""))
    }

    func removeTopic(_ topicID: UUID, from serverID: UUID) {
        guard let serverIndex = servers.firstIndex(where: { $0.id == serverID }) else { return }
        servers[serverIndex].topics.removeAll { $0.id == topicID }
    }

    // MARK: - Binding helpers

    func serverBinding(for id: UUID) -> EditableServer? {
        servers.first { $0.id == id }
    }

    var selectedServer: EditableServer? {
        guard let id = selectedServerID else { return nil }
        return servers.first { $0.id == id }
    }

    func selectedServerIndex() -> Int? {
        guard let id = selectedServerID else { return nil }
        return servers.firstIndex { $0.id == id }
    }
}
