import Foundation

/// Protocol for script execution - enables dependency injection and mocking for tests
protocol ScriptRunnerProtocol: Sendable {
    /// Runs a shell script asynchronously with the message body as an argument
    func runScript(at path: String, withArgument argument: String?, extraEnv: [String: String]?)
    
    /// Validates that a script exists and is executable
    func validateScript(at path: String) -> Bool
    
    /// Runs a macOS Shortcut asynchronously
    func runShortcut(named shortcutName: String, withInput input: String?)
    
    /// Runs an AppleScript from an inline script string
    func runAppleScript(source: String)
    
    /// Runs an AppleScript from a file path
    func runAppleScriptFile(at path: String)
}

final class ScriptRunner: ScriptRunnerProtocol, @unchecked Sendable {
    /// Enhanced PATH for script execution including common Homebrew and system directories
    private let enhancedPATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    /// Runs a shell script asynchronously with the message body as an argument
    /// Additional message context can be passed via environment variables
    func runScript(at path: String, withArgument argument: String? = nil, extraEnv: [String: String]? = nil) {
        DispatchQueue.global(qos: .utility).async { [enhancedPATH = self.enhancedPATH] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [path]

            if let argument = argument {
                process.arguments?.append(argument)
            }

            // Set up environment with enhanced PATH
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = enhancedPATH
            if let extraEnv = extraEnv {
                for (key, value) in extraEnv {
                    environment[key] = value
                }
            }
            process.environment = environment

            // Capture output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                print("Executing script: \(path)")
                if let argument = argument {
                    print("With argument: \(argument)")
                }

                try process.run()

                // Read output asynchronously
                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading

                outputHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                        print("Script output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }

                errorHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let error = String(data: data, encoding: .utf8) {
                        print("Script error: \(error.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }

                process.waitUntilExit()

                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil

                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    print("Script completed successfully")
                } else {
                    print("Script exited with code: \(exitCode)")
                }

            } catch {
                print("Failed to execute script: \(error)")
            }
        }
    }

    /// Validates that a script exists and is executable
    func validateScript(at path: String) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            print("Script not found or is a directory: \(path)")
            return false
        }

        guard fileManager.isExecutableFile(atPath: path) else {
            print("Script is not executable: \(path)")
            return false
        }

        return true
    }

    /// Runs a macOS Shortcut asynchronously with an optional input string
    func runShortcut(named shortcutName: String, withInput input: String? = nil) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            var args = ["run", shortcutName]
            if let input = input {
                args.append(contentsOf: ["-i", input])
            }
            process.arguments = args

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                Log.info("Running shortcut: \(shortcutName)")
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    Log.success("Shortcut '\(shortcutName)' completed successfully")
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                    Log.error("Shortcut '\(shortcutName)' exited with code \(exitCode): \(errorStr)")
                }
            } catch {
                Log.error("Failed to run shortcut '\(shortcutName)': \(error)")
            }
        }
    }

    /// Runs an AppleScript from an inline script string
    func runAppleScript(source: String) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                Log.info("Running AppleScript (inline)")
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                        Log.info("AppleScript output: \(output)")
                    }
                    Log.success("AppleScript completed successfully")
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                    Log.error("AppleScript exited with code \(exitCode): \(errorStr)")
                }
            } catch {
                Log.error("Failed to run AppleScript: \(error)")
            }
        }
    }

    /// Runs an AppleScript from a file path
    func runAppleScriptFile(at path: String) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [path]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                Log.info("Running AppleScript file: \(path)")
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if exitCode == 0 {
                    Log.success("AppleScript file completed successfully")
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                    Log.error("AppleScript file exited with code \(exitCode): \(errorStr)")
                }
            } catch {
                Log.error("Failed to run AppleScript file: \(error)")
            }
        }
    }

    /// Runs a script synchronously and returns the output (useful for testing)
    func runScriptSynchronously(at path: String, withArgument argument: String? = nil, extraEnv: [String: String]? = nil) -> (exitCode: Int32, output: String, error: String) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return (-1, "", "Failed to execute: Script not found or is a directory")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [path]

        if let argument = argument {
            process.arguments?.append(argument)
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = enhancedPATH
        if let extraEnv = extraEnv {
            for (key, value) in extraEnv {
                environment[key] = value
            }
        }
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return (process.terminationStatus, output, error)
        } catch {
            return (-1, "", "Failed to execute: \(error.localizedDescription)")
        }
    }
}
