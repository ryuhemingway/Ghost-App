import Foundation

struct DeterministicCalendarQuery: Sendable, Equatable {
    let startDate: Date
    let endDate: Date
    let label: String
    let confidence: Double

    func formattedRange(calendar: Calendar = .current) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate.addingTimeInterval(-1))
    }
}

struct DeterministicCalendarQueryParser: Sendable {
    func parse(
        _ rawPrompt: String,
        now: Date = Date(),
        calendar inputCalendar: Calendar = .current
    ) -> DeterministicCalendarQuery? {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }

        let lower = prompt.lowercased()

        // Do not intercept event creation. Let the local-model tool loop or agent create events.
        if lower.range(
            of: #"^\s*(add|create|schedule|book|put|make|set up|invite)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return nil
        }

        let mentionsCalendar = containsAnyWordOrPhrase(lower, [
            "calendar", "schedule", "agenda", "events", "meetings", "appointments", "plans", "plan"
        ])
        guard mentionsCalendar else { return nil }

        let asksToReadCalendar = lower.contains("?")
            || hasLeadingWordOrPhrase(lower, [
                "what", "when", "where", "show", "list", "tell", "tell me", "do i", "do we", "what do i", "what's", "whats", "anything"
            ])
            || containsAnyWordOrPhrase(lower, [
                "what do i have", "what have i got", "what is on", "what's on", "whats on", "upcoming", "next on", "plans for", "agenda for"
            ])

        guard asksToReadCalendar else { return nil }

        var calendar = inputCalendar
        calendar.timeZone = .autoupdatingCurrent

        let startOfToday = calendar.startOfDay(for: now)

        if containsAnyWordOrPhrase(lower, ["next week"]) {
            guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
                  let start = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek.start),
                  let end = calendar.date(byAdding: .weekOfYear, value: 2, to: thisWeek.start)
            else { return nil }
            return DeterministicCalendarQuery(
                startDate: start,
                endDate: end,
                label: "next week",
                confidence: 0.96
            )
        }

        if containsAnyWordOrPhrase(lower, ["this week", "week ahead"]) {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            return DeterministicCalendarQuery(
                startDate: max(now, interval.start),
                endDate: interval.end,
                label: "this week",
                confidence: 0.92
            )
        }

        if containsAnyWordOrPhrase(lower, ["tomorrow"]) {
            guard let start = calendar.date(byAdding: .day, value: 1, to: startOfToday),
                  let end = calendar.date(byAdding: .day, value: 2, to: startOfToday)
            else { return nil }
            return DeterministicCalendarQuery(
                startDate: start,
                endDate: end,
                label: "tomorrow",
                confidence: 0.94
            )
        }

        if containsAnyWordOrPhrase(lower, ["today"]) {
            guard let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }
            return DeterministicCalendarQuery(
                startDate: now,
                endDate: end,
                label: "today",
                confidence: 0.93
            )
        }

        if containsAnyWordOrPhrase(lower, ["tonight"]) {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 23
            components.minute = 59
            components.second = 59
            guard let end = calendar.date(from: components), end > now else { return nil }
            return DeterministicCalendarQuery(
                startDate: now,
                endDate: end,
                label: "tonight",
                confidence: 0.90
            )
        }

        if containsAnyWordOrPhrase(lower, ["this weekend", "weekend"]) {
            let weekday = calendar.component(.weekday, from: now)
            let saturday = 7
            let daysUntilSaturday = (saturday - weekday + 7) % 7
            guard let start = calendar.date(byAdding: .day, value: daysUntilSaturday, to: startOfToday),
                  let end = calendar.date(byAdding: .day, value: daysUntilSaturday + 2, to: startOfToday)
            else { return nil }
            return DeterministicCalendarQuery(
                startDate: max(now, start),
                endDate: end,
                label: "this weekend",
                confidence: 0.86
            )
        }

        // Safe default for read-only calendar questions: show the next 7 days.
        guard let end = calendar.date(byAdding: .day, value: 7, to: now) else { return nil }
        return DeterministicCalendarQuery(
            startDate: now,
            endDate: end,
            label: "the next 7 days",
            confidence: 0.76
        )
    }

    private func hasLeadingWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"^\s*"# + escaped + #"\b"#

            return value.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private func containsAnyWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"\b"# + escaped + #"\b"#

            return value.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }
}
