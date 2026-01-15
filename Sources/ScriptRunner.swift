import Foundation

final class ScriptRunner: @unchecked Sendable {
    /// Enhanced PATH for script execution including common Homebrew and system directories
    private let enhancedPATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    /// Runs a shell script asynchronously with the message body as an argument
    func runScript(at path: String, withArgument argument: String? = nil) {
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

    /// Runs a script synchronously and returns the output (useful for testing)
    func runScriptSynchronously(at path: String, withArgument argument: String? = nil) -> (exitCode: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [path]

        if let argument = argument {
            process.arguments?.append(argument)
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = enhancedPATH
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
