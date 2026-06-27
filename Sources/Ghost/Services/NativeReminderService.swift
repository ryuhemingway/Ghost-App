import Foundation
import EventKit

struct NativeReminderResult: Sendable {
    let title: String
    let dueDate: Date
    let backend: String
    let identifier: String?

    func confirmationText(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Reminder set for \(formatter.string(from: dueDate)): \(title)"
    }
}

struct NativeReminderService: Sendable {
    func createReminder(_ reminder: ParsedReminder) async throws -> NativeReminderResult {
        do {
            return try await createEventKitReminder(title: reminder.title, dueDate: reminder.dueDate)
        } catch {
            return try await createAppleScriptReminder(title: reminder.title, dueDate: reminder.dueDate, eventKitError: error)
        }
    }

    func createReminder(title: String, dueDate: Date) async throws -> NativeReminderResult {
        let reminder = ParsedReminder(title: title, dueDate: dueDate, sourceText: title, confidence: 1.0)
        return try await createReminder(reminder)
    }

    private func createEventKitReminder(title: String, dueDate: Date) async throws -> NativeReminderResult {
        let store = EKEventStore()
        let granted = try await requestReminderAccess(store)
        guard granted else {
            throw ReminderError.accessDenied
        }

        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw ReminderError.noDefaultReminderList
        }

        var userCalendar = Calendar.current
        userCalendar.timeZone = TimeZone.current
        let components = userCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)

        let item = EKReminder(eventStore: store)
        item.title = title
        item.calendar = calendar
        item.dueDateComponents = components
        item.addAlarm(EKAlarm(absoluteDate: dueDate))

        try store.save(item, commit: true)
        return NativeReminderResult(title: title, dueDate: dueDate, backend: "Reminders", identifier: item.calendarItemIdentifier)
    }

    private func requestReminderAccess(_ store: EKEventStore) async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func createAppleScriptReminder(
        title: String,
        dueDate: Date,
        eventKitError: Error
    ) async throws -> NativeReminderResult {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute
        else {
            throw eventKitError
        }

        let script = """
        set reminderTitle to \"\(appleScriptEscaped(title))\"
        set dueDate to current date
        set year of dueDate to \(year)
        set month of dueDate to \(appleScriptMonthName(month))
        set day of dueDate to \(day)
        set hours of dueDate to \(hour)
        set minutes of dueDate to \(minute)
        set seconds of dueDate to 0
        tell application \"Reminders\"
            set targetList to default list
            set newReminder to make new reminder at end of reminders of targetList with properties {name:reminderTitle, due date:dueDate, remind me date:dueDate}
            return id of newReminder
        end tell
        """

        let output = try await runOSAScript(script)
        return NativeReminderResult(
            title: title,
            dueDate: dueDate,
            backend: "Reminders via AppleScript",
            identifier: output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func runOSAScript(_ script: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let error = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

            guard process.terminationStatus == 0 else {
                let trimmedError = error.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ReminderError.appleScriptFailed(trimmedError.isEmpty ? "osascript failed" : trimmedError)
            }

            return output
        }.value
    }

    private func appleScriptMonthName(_ month: Int) -> String {
        [
            1: "January", 2: "February", 3: "March", 4: "April", 5: "May", 6: "June",
            7: "July", 8: "August", 9: "September", 10: "October", 11: "November", 12: "December"
        ][month] ?? "January"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum ReminderError: LocalizedError {
    case accessDenied
    case noDefaultReminderList
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Ghost needs Reminders permission to create this reminder. Enable Reminders access in System Settings > Privacy & Security, then try again."
        case .noDefaultReminderList:
            return "Could not find a default Reminders list. Open the Reminders app once, make sure a list exists, then try again."
        case .appleScriptFailed(let message):
            return "Could not create the reminder through Reminders: \(message)"
        }
    }
}
