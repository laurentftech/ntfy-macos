import Foundation

/// Watches the configuration file for changes and triggers reload
final class ConfigWatcher: @unchecked Sendable {
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let configPath: String
    private let lock = NSLock()
    private var _onConfigChanged: (() -> Void)?

    init(configPath: String? = nil) {
        self.configPath = configPath ?? ConfigManager.defaultConfigPath
    }

    /// Starts watching the configuration file for changes
    func startWatching(onConfigChanged: @escaping () -> Void) {
        lock.lock()
        self._onConfigChanged = onConfigChanged
        lock.unlock()

        // Open file descriptor for watching
        fileDescriptor = open(configPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("⚠️  Could not watch config file for changes: \(configPath)")
            return
        }

        // Create dispatch source to monitor file changes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: DispatchQueue.main
        )

        let path = configPath
        source.setEventHandler { [weak self] in
            guard let self = self else { return }

            let flags = source.data

            // If file was deleted or renamed, we need to re-establish the watch
            if flags.contains(.delete) || flags.contains(.rename) {
                self.stopWatching()

                // Wait a bit for the file to be recreated (common with atomic writes)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Check if file exists again
                    if FileManager.default.fileExists(atPath: path) {
                        print("📁 Config file recreated, reloading...")
                        self.lock.lock()
                        let callback = self._onConfigChanged
                        self.lock.unlock()
                        callback?()
                        if let cb = callback {
                            self.startWatching(onConfigChanged: cb)
                        }
                    }
                }
            } else {
                // File was modified
                print("📁 Config file changed, reloading...")
                self.lock.lock()
                let callback = self._onConfigChanged
                self.lock.unlock()
                callback?()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        dispatchSource = source
        source.resume()

        print("👀 Watching config file for changes: \(configPath)")
    }

    /// Stops watching the configuration file
    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    deinit {
        stopWatching()
    }
}
