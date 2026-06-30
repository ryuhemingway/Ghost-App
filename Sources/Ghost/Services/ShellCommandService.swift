import Foundation

struct ShellCommandResult: Sendable {
    let command: String
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let timedOut: Bool
    let duration: TimeInterval
    let finalWorkingDirectory: String?

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

        if let finalWorkingDirectory, !finalWorkingDirectory.isEmpty {
            parts.append("[cwd]\n\(finalWorkingDirectory)")
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
            let sentinel = "__GHOST_FINAL_PWD__="
            let wrappedCommand = """
            \(command)
            __ghost_status=$?
            printf '\\n\(sentinel)%s\\n' "$PWD"
            exit $__ghost_status
            """

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lic", wrappedCommand]
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
                        duration: Date().timeIntervalSince(startedAt),
                        finalWorkingDirectory: nil
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

                let rawStdout = String(data: outputData, encoding: .utf8) ?? ""
                let parsed = parseFinalWorkingDirectory(from: rawStdout, sentinel: sentinel)
                let result = ShellCommandResult(
                    command: command,
                    stdout: parsed.stdout,
                    stderr: String(data: errorData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus,
                    timedOut: state.timedOut,
                    duration: Date().timeIntervalSince(startedAt),
                    finalWorkingDirectory: parsed.cwd
                )
                state.resumeOnce(continuation, with: result)
            }
        }
    }

    private func parseFinalWorkingDirectory(from stdout: String, sentinel: String) -> (stdout: String, cwd: String?) {
        guard let range = stdout.range(of: sentinel, options: .backwards) else {
            return (stdout, nil)
        }

        let before = String(stdout[..<range.lowerBound])
        let after = stdout[range.upperBound...]
        let cwd = after.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (before.trimmingCharacters(in: .newlines), cwd?.isEmpty == false ? cwd : nil)
    }

    private func shellEnvironment(workingDirectory: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["PWD"] = workingDirectory.path
        environment["GHOST_CWD"] = workingDirectory.path
        environment["TERM"] = "xterm-256color"
        environment["TERM_PROGRAM"] = "Ghost"
        environment["COLORTERM"] = "truecolor"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        environment["LC_ALL"] = environment["LC_ALL"] ?? "en_US.UTF-8"
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
