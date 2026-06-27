import Foundation

struct ParsedReminder: Equatable, Sendable {
    let title: String
    let dueDate: Date
    let sourceText: String
    let confidence: Double

    func formattedDueDate(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
}

struct DeterministicReminderParser: Sendable {
    func parse(_ rawText: String, now: Date = Date(), calendar inputCalendar: Calendar = .current) -> ParsedReminder? {
        let source = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return nil }

        let lower = source.lowercased()
        guard isReminderRequest(lower) else { return nil }
        guard !isRecurringOrConditional(lower) else { return nil }

        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone

        var removalRanges: [Range<String.Index>] = []
        var dueDate: Date?
        var confidence = 0.92

        if let relative = relativeOffset(in: source, now: now, calendar: calendar) {
            dueDate = relative.date
            removalRanges.append(relative.range)
            confidence = 0.98
        } else if let absolute = absoluteDateTime(in: source, now: now, calendar: calendar) {
            dueDate = absolute.date
            removalRanges.append(contentsOf: absolute.ranges)
            confidence = absolute.confidence
        }

        guard let date = dueDate, date > now.addingTimeInterval(20) else {
            return nil
        }

        let title = reminderTitle(from: source, removing: removalRanges)
        guard title.count >= 2 else { return nil }

        return ParsedReminder(
            title: title,
            dueDate: date,
            sourceText: source,
            confidence: confidence
        )
    }

    private func isReminderRequest(_ lower: String) -> Bool {
        lower.range(of: #"\b(remind|notify|alert)\s+me\b"#, options: .regularExpression) != nil
            || lower.range(of: #"\bset\s+(?:a\s+)?reminder\b"#, options: .regularExpression) != nil
    }

    private func isRecurringOrConditional(_ lower: String) -> Bool {
        let recurringCues = [
            "every day", "every morning", "every night", "every week", "every month", "every year",
            "daily", "weekly", "monthly", "yearly", "recurring", "repeat", "repeating",
            "whenever", "monitor", "watch for", "keep checking", "until", "each day", "each week"
        ]
        if recurringCues.contains(where: { lower.contains($0) }) {
            return true
        }

        // Phrases like "when I get home" need location/condition handling instead of a one-shot parser.
        if lower.range(of: #"\b(?:when|if)\s+i\b"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func relativeOffset(
        in source: String,
        now: Date,
        calendar: Calendar
    ) -> (date: Date, range: Range<String.Index>)? {
        guard let match = firstRegexMatch(
            #"\bin\s+(\d{1,4})\s*(minutes?|mins?|m|hours?|hrs?|h|days?|weeks?)\b"#,
            in: source
        ), match.captures.count >= 2,
           let amountText = match.captures[0],
           let amount = Int(amountText), amount > 0,
           let unit = match.captures[1]?.lowercased()
        else {
            return nil
        }

        let component: Calendar.Component
        switch unit {
        case "minute", "minutes", "min", "mins", "m":
            component = .minute
        case "hour", "hours", "hr", "hrs", "h":
            component = .hour
        case "day", "days":
            component = .day
        case "week", "weeks":
            component = .weekOfYear
        default:
            return nil
        }

        guard let date = calendar.date(byAdding: component, value: amount, to: now) else {
            return nil
        }

        return (date, match.range)
    }

    private func absoluteDateTime(
        in source: String,
        now: Date,
        calendar: Calendar
    ) -> (date: Date, ranges: [Range<String.Index>], confidence: Double)? {
        var ranges: [Range<String.Index>] = []
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        components.second = 0

        let dayContext = dayContext(in: source, now: now, calendar: calendar)
        if let dayContext {
            components.year = calendar.component(.year, from: dayContext.date)
            components.month = calendar.component(.month, from: dayContext.date)
            components.day = calendar.component(.day, from: dayContext.date)
            ranges.append(dayContext.range)
        }

        guard let time = timeContext(in: source, dayHint: dayContext?.hint) else {
            // Only accept daypart-only reminders for explicit phrases like "tomorrow morning".
            guard let dayContext, let fallback = fallbackTime(for: dayContext.hint) else {
                return nil
            }
            components.hour = fallback.hour
            components.minute = fallback.minute
            let raw = calendar.date(from: components)
            guard let date = raw.map({ adjustedFutureDate($0, now: now, calendar: calendar, dayWasExplicit: true) }) else {
                return nil
            }
            return (date, ranges, 0.82)
        }

        components.hour = time.hour
        components.minute = time.minute
        ranges.append(time.range)

        guard let rawDate = calendar.date(from: components) else { return nil }
        let date = adjustedFutureDate(rawDate, now: now, calendar: calendar, dayWasExplicit: dayContext != nil)
        return (date, ranges, dayContext == nil ? 0.90 : 0.96)
    }

    private enum DayHint {
        case today
        case tomorrow
        case tonight
        case morning
        case afternoon
        case evening
        case weekday
    }

    private func dayContext(
        in source: String,
        now: Date,
        calendar: Calendar
    ) -> (date: Date, range: Range<String.Index>, hint: DayHint)? {
        let simplePatterns: [(String, Int, DayHint)] = [
            (#"\btoday\b"#, 0, .today),
            (#"\bthis\s+morning\b"#, 0, .morning),
            (#"\bthis\s+afternoon\b"#, 0, .afternoon),
            (#"\bthis\s+evening\b"#, 0, .evening),
            (#"\btonight\b"#, 0, .tonight),
            (#"\btomorrow\s+morning\b"#, 1, .morning),
            (#"\btomorrow\s+afternoon\b"#, 1, .afternoon),
            (#"\btomorrow\s+evening\b"#, 1, .evening),
            (#"\btomorrow\s+night\b"#, 1, .tonight),
            (#"\btomorrow\b"#, 1, .tomorrow)
        ]

        for (pattern, offset, hint) in simplePatterns {
            if let match = firstRegexMatch(pattern, in: source),
               let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                return (date, match.range, hint)
            }
        }

        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7
        ]

        for (name, weekday) in weekdays {
            let pattern = #"\b(?:on\s+)?"# + NSRegularExpression.escapedPattern(for: name) + #"\b"#
            guard let match = firstRegexMatch(pattern, in: source) else { continue }

            let todayWeekday = calendar.component(.weekday, from: now)
            var delta = weekday - todayWeekday
            if delta < 0 { delta += 7 }
            guard let date = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: now)) else {
                continue
            }
            return (date, match.range, .weekday)
        }

        return nil
    }

    private func timeContext(
        in source: String,
        dayHint: DayHint?
    ) -> (hour: Int, minute: Int, range: Range<String.Index>)? {
        guard let match = firstRegexMatch(#"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\b"#, in: source),
              match.captures.count >= 3,
              let hourText = match.captures[0],
              var hour = Int(hourText)
        else {
            return nil
        }

        let minute = match.captures[1].flatMap(Int.init) ?? 0
        guard (0...59).contains(minute) else { return nil }

        let meridiem = match.captures[2]?.lowercased().replacingOccurrences(of: ".", with: "")
        if let meridiem {
            guard (1...12).contains(hour) else { return nil }
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
        } else {
            guard (0...23).contains(hour) else { return nil }
            if [.tonight, .evening].contains(dayHint), (1...11).contains(hour) {
                hour += 12
            } else if dayHint == .afternoon, (1...6).contains(hour) {
                hour += 12
            }
        }

        return (hour, minute, match.range)
    }

    private func fallbackTime(for hint: DayHint) -> (hour: Int, minute: Int)? {
        switch hint {
        case .morning:
            return (9, 0)
        case .afternoon:
            return (15, 0)
        case .evening:
            return (19, 0)
        case .tonight:
            return (21, 0)
        case .today, .tomorrow, .weekday:
            return nil
        }
    }

    private func adjustedFutureDate(
        _ date: Date,
        now: Date,
        calendar: Calendar,
        dayWasExplicit: Bool
    ) -> Date {
        guard date <= now.addingTimeInterval(20) else { return date }

        if dayWasExplicit {
            // Explicit weekdays such as "Friday at 9" should move to next week only when the same-day time has passed.
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }

        return calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private func reminderTitle(from source: String, removing ranges: [Range<String.Index>]) -> String {
        var text = source

        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            text.removeSubrange(range)
        }

        let cleanupPatterns = [
            #"(?i)^\s*please\s+"#,
            #"(?i)^\s*(?:remind|notify|alert)\s+me\s*"#,
            #"(?i)^\s*set\s+(?:a\s+)?reminder\s*"#,
            #"(?i)^\s*(?:that|to|about)\s+"#,
            #"(?i)^\s*for\s+me\s+to\s+"#,
            #"(?i)\s+(?:that|to)\s*$"#
        ]

        for pattern in cleanupPatterns {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        text = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        if text.lowercased().hasPrefix("that ") {
            text = String(text.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.lowercased().hasPrefix("to ") {
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text.isEmpty ? "Reminder" : text
    }

    private struct RegexMatch {
        let range: Range<String.Index>
        let captures: [String?]
    }

    private func firstRegexMatch(_ pattern: String, in source: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: nsRange),
              let fullRange = Range(match.range, in: source)
        else {
            return nil
        }

        let captures = (1..<match.numberOfRanges).map { index -> String? in
            guard let range = Range(match.range(at: index), in: source) else { return nil }
            return String(source[range])
        }

        return RegexMatch(range: fullRange, captures: captures)
    }
}
