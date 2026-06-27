import Foundation
import EventKit

struct NativeCalendarEventResult: Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let identifier: String?

    func confirmationText(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Calendar event created for \(formatter.string(from: startDate)): \(title)"
    }
}

struct NativeCalendarEventSummary: Sendable, Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let identifier: String?
}

struct NativeCalendarService: Sendable {
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        location: String? = nil
    ) async throws -> NativeCalendarEventResult {
        let store = EKEventStore()
        let granted = try await requestCalendarAccess(store)
        guard granted else {
            throw CalendarServiceError.accessDenied
        }

        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarServiceError.noDefaultCalendar
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.notes = notes
        event.location = location
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))

        try store.save(event, span: .thisEvent, commit: true)
        return NativeCalendarEventResult(
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarTitle: calendar.title,
            identifier: event.eventIdentifier
        )
    }

    func queryEvents(
        startDate: Date,
        endDate: Date,
        matching searchText: String? = nil,
        limit: Int = 50
    ) async throws -> [NativeCalendarEventSummary] {
        guard endDate > startDate else {
            throw CalendarServiceError.invalidDateRange
        }

        let store = EKEventStore()
        let granted = try await requestCalendarAccess(store)
        guard granted else {
            throw CalendarServiceError.accessDenied
        }

        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars.isEmpty ? nil : calendars
        )

        let normalizedSearch = searchText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nonEmpty

        let events = store.events(matching: predicate)
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return (lhs.title ?? "") < (rhs.title ?? "")
                }
                return lhs.startDate < rhs.startDate
            }
            .filter { event in
                guard let normalizedSearch else { return true }
                let haystack = [
                    event.title,
                    event.location,
                    event.notes,
                    event.calendar.title
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
                .lowercased()

                return haystack.contains(normalizedSearch)
            }
            .prefix(max(limit, 1))

        return events.map { event in
            NativeCalendarEventSummary(
                title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled event",
                startDate: event.startDate,
                endDate: event.endDate,
                calendarTitle: event.calendar.title,
                location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
                notes: event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
                isAllDay: event.isAllDay,
                identifier: event.eventIdentifier
            )
        }
    }

    private func requestCalendarAccess(_ store: EKEventStore) async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
}

enum CalendarServiceError: LocalizedError {
    case accessDenied
    case noDefaultCalendar
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Ghost needs Calendar permission. Enable Calendar access in System Settings > Privacy & Security, then try again."
        case .noDefaultCalendar:
            return "Could not find a default Calendar. Open the Calendar app once, make sure a calendar exists, then try again."
        case .invalidDateRange:
            return "The calendar end time must be after its start time."
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
