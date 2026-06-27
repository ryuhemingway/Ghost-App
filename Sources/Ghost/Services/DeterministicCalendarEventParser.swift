import Foundation

struct DeterministicCalendarEvent: Sendable, Equatable {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let location: String?
    let confidence: Double

    func formattedTime(calendar: Calendar = .current) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate, to: endDate)
    }
}

struct DeterministicCalendarEventParser: Sendable {
    func parse(
        _ rawPrompt: String,
        now: Date = Date(),
        calendar inputCalendar: Calendar = .current
    ) -> DeterministicCalendarEvent? {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }
        let lower = prompt.lowercased()

        guard isEventCreationPrompt(lower) else { return nil }
        guard let time = parseTime(in: lower) else { return nil }

        let calendar = inputCalendar

        guard let day = parseDay(in: lower, now: now, calendar: calendar) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        guard let start = calendar.date(from: components) else { return nil }
        let durationMinutes = parseDurationMinutes(in: lower) ?? 30
        let end = parseExplicitEndTime(in: lower, start: start, calendar: calendar)
            ?? calendar.date(byAdding: .minute, value: durationMinutes, to: start)
            ?? start.addingTimeInterval(TimeInterval(durationMinutes * 60))

        guard end > start else { return nil }

        let title = extractTitle(from: prompt, lower: lower)
        guard !title.isEmpty else { return nil }

        return DeterministicCalendarEvent(
            title: title,
            startDate: start,
            endDate: end,
            notes: nil,
            location: extractLocation(from: prompt),
            confidence: 0.90
        )
    }

    private func isEventCreationPrompt(_ lower: String) -> Bool {
        let startsWithCreateVerb = lower.range(
            of: #"^\s*(add|create|schedule|book|put|make|set up)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        guard startsWithCreateVerb else { return false }
        if containsAnyWordOrPhrase(lower, ["reminder", "remind me", "timer", "alarm"]) {
            return false
        }

        return containsAnyWordOrPhrase(lower, [
            "calendar event", "event", "meeting", "appointment", "call", "class", "dentist", "doctor"
        ]) || lower.hasPrefix("schedule ") || lower.hasPrefix("book ")
    }

    private func parseDay(in lower: String, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        if containsAnyWordOrPhrase(lower, ["today"]) { return today }
        if containsAnyWordOrPhrase(lower, ["tomorrow"]) {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if containsAnyWordOrPhrase(lower, ["tonight"]) { return today }

        let weekdays: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7)
        ]

        for (name, weekday) in weekdays where containsAnyWordOrPhrase(lower, [name, String(name.prefix(3))]) {
            let currentWeekday = calendar.component(.weekday, from: today)
            var delta = (weekday - currentWeekday + 7) % 7
            if delta == 0 || lower.contains("next \(name)") || lower.contains("next \(name.prefix(3))") {
                delta = delta == 0 ? 7 : delta
            }
            return calendar.date(byAdding: .day, value: delta, to: today)
        }

        return nil
    }

    private func parseTime(in lower: String) -> (hour: Int, minute: Int)? {
        if let match = firstMatch(
            pattern: #"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#,
            in: lower
        ), match.count >= 4 {
            return normalizeHour(hourText: match[1], minuteText: match[2], meridiem: match[3])
        }

        if let match = firstMatch(
            pattern: #"\b(\d{1,2})(?::(\d{2}))\s*(am|pm)\b"#,
            in: lower
        ), match.count >= 4 {
            return normalizeHour(hourText: match[1], minuteText: match[2], meridiem: match[3])
        }

        if let match = firstMatch(
            pattern: #"\b(\d{1,2})\s*(am|pm)\b"#,
            in: lower
        ), match.count >= 3 {
            return normalizeHour(hourText: match[1], minuteText: nil, meridiem: match[2])
        }

        if let match = firstMatch(
            pattern: #"\bat\s+(\d{1,2}):(\d{2})\b"#,
            in: lower
        ), match.count >= 3,
           let hour = Int(match[1]), let minute = Int(match[2]),
           (0...23).contains(hour), (0...59).contains(minute) {
            return (hour, minute)
        }

        return nil
    }

    private func normalizeHour(hourText: String, minuteText: String?, meridiem: String) -> (hour: Int, minute: Int)? {
        guard var hour = Int(hourText) else { return nil }
        let minute = Int(minuteText ?? "0") ?? 0
        guard (1...12).contains(hour), (0...59).contains(minute) else { return nil }
        if meridiem == "pm", hour < 12 { hour += 12 }
        if meridiem == "am", hour == 12 { hour = 0 }
        return (hour, minute)
    }

    private func parseDurationMinutes(in lower: String) -> Int? {
        if let match = firstMatch(pattern: #"\bfor\s+(\d{1,3})\s*(minutes|min|mins)\b"#, in: lower),
           match.count >= 2,
           let value = Int(match[1]) {
            return min(max(value, 5), 24 * 60)
        }
        if let match = firstMatch(pattern: #"\bfor\s+(\d{1,2})\s*(hour|hours|hr|hrs)\b"#, in: lower),
           match.count >= 2,
           let value = Int(match[1]) {
            return min(max(value * 60, 5), 24 * 60)
        }
        return nil
    }

    private func parseExplicitEndTime(in lower: String, start: Date, calendar: Calendar) -> Date? {
        guard let match = firstMatch(
            pattern: #"\b(?:to|until|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#,
            in: lower
        ), match.count >= 4 else { return nil }

        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        let inferredMeridiem: String
        if !match[3].isEmpty {
            inferredMeridiem = match[3]
        } else {
            inferredMeridiem = (startComponents.hour ?? 12) >= 12 ? "pm" : "am"
        }

        guard let endTime = normalizeHour(hourText: match[1], minuteText: match[2].isEmpty ? nil : match[2], meridiem: inferredMeridiem) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: start)
        components.hour = endTime.hour
        components.minute = endTime.minute
        components.second = 0
        guard let end = calendar.date(from: components) else { return nil }
        return end > start ? end : calendar.date(byAdding: .day, value: 1, to: end)
    }

    private func extractTitle(from prompt: String, lower: String) -> String {
        if let match = firstMatch(
            pattern: #"\b(?:called|titled|named)\s+[\"']?([^\"'.,\n]+)[\"']?"#,
            in: prompt
        ), match.count >= 2 {
            return cleanTitle(match[1])
        }

        var title = prompt
        title = title.replacingOccurrences(
            of: #"^\s*(add|create|schedule|book|put|make|set up)\s+(a|an|the)?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: #"\b(calendar\s+event|event|meeting|appointment)\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: #"\b(today|tomorrow|tonight|next\s+\w+|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: #"\b(at|from|to|until|for)\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: #"\bfor\s+\d{1,3}\s*(minutes|min|mins|hour|hours|hr|hrs)\b"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return cleanTitle(title)
    }

    private func cleanTitle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,-–—:;\"'"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func extractLocation(from prompt: String) -> String? {
        guard let match = firstMatch(
            pattern: #"\b(?:location|where)[:=]\s*([^.,\n]+)"#,
            in: prompt
        ), match.count >= 2 else {
            return nil
        }
        let location = cleanTitle(match[1])
        return location.isEmpty ? nil : location
    }

    private func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: text)
            else { return "" }
            return String(text[range])
        }
    }

    private func containsAnyWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"\b"# + escaped + #"\b"#
            return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
