import Foundation

struct ShellCommandResult: Sendable {
    let command: String
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let timedOut: Bool
    let duration: TimeInterval

    var formattedTerminalOutput: String {
        var parts: [String] = []
        parts.append("[cmd]\n\(command)")

        let cleanStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanStdout.isEmpty {
            parts.append("[stdout]\n\(cleanStdout)")
        }

        let cleanStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanStderr.isEmpty {
            parts.append("[stderr]\n\(cleanStderr)")
        }

        if timedOut {
            parts.append("[timeout]\nCommand exceeded the time limit and was stopped.")
        }

        parts.append("[exit \(exitCode)] \(String(format: "%.2fs", duration))")
        return parts.joined(separator: "\n\n")
    }
}

struct ShellCommandService: Sendable {
    func run(
        _ command: String,
        workingDirectory: URL,
        timeout: TimeInterval = 120
    ) async -> ShellCommandResult {
        await withCheckedContinuation { continuation in
            let startedAt = Date()
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let state = ShellCommandState()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            process.currentDirectoryURL = workingDirectory
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = shellEnvironment(workingDirectory: workingDirectory)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                } catch {
                    let result = ShellCommandResult(
                        command: command,
                        stdout: "",
                        stderr: "Could not launch command: \(error.localizedDescription)",
                        exitCode: 127,
                        timedOut: false,
                        duration: Date().timeIntervalSince(startedAt)
                    )
                    state.resumeOnce(continuation, with: result)
                    return
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    state.markTimedOut()
                    process.terminate()

                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        if process.isRunning {
                            process.interrupt()
                        }
                    }
                }

                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let result = ShellCommandResult(
                    command: command,
                    stdout: String(data: outputData, encoding: .utf8) ?? "",
                    stderr: String(data: errorData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus,
                    timedOut: state.timedOut,
                    duration: Date().timeIntervalSince(startedAt)
                )
                state.resumeOnce(continuation, with: result)
            }
        }
    }

    private func shellEnvironment(workingDirectory: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["PWD"] = workingDirectory.path
        environment["GHOST_CWD"] = workingDirectory.path
        environment["TERM"] = "xterm-256color"
        environment["PATH"] = [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        return environment
    }
}

private final class ShellCommandState: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private var _timedOut = false

    var timedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _timedOut
    }

    func markTimedOut() {
        lock.lock()
        _timedOut = true
        lock.unlock()
    }

    func resumeOnce(
        _ continuation: CheckedContinuation<ShellCommandResult, Never>,
        with result: ShellCommandResult
    ) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()
        continuation.resume(returning: result)
    }
}
