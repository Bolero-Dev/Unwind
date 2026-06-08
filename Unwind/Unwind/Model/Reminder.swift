//
//  Reminder.swift
//  Unwind
//
//  SwiftData model for a recurring weekly reminder: a time of day plus the set
//  of weekdays it should fire on (e.g. "8:00 PM on Mon / Wed / Fri").
//
//  Created by Leah Cluff on 4/10/23.
//

import Foundation
import SwiftData

@Model
final class Reminder {
    /// Stable id used to name the underlying notification requests.
    var id: UUID
    var label: String
    var hour: Int          // 0...23
    var minute: Int        // 0...59
    /// Weekdays this reminder fires on. 1 = Sunday ... 7 = Saturday,
    /// matching `Calendar` / `DateComponents.weekday`.
    var weekdays: [Int]
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String = "",
        hour: Int = 20,
        minute: Int = 0,
        weekdays: [Int] = [],
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

extension Reminder {
    /// The time of day as a `Date` (today's date with this hour/minute), handy
    /// for binding to a `DatePicker` and for formatting.
    var time: Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: .now
        ) ?? .now
    }

    /// "8:00 PM" — localized.
    var timeString: String {
        time.formatted(date: .omitted, time: .shortened)
    }

    /// "Mon, Wed, Fri", "Every day", "Weekends", or "Never" if none selected.
    var weekdaysString: String {
        let sorted = weekdays.sorted()
        switch Set(sorted) {
        case Set(1...7):        return "Every day"
        case [2, 3, 4, 5, 6]:   return "Weekdays"
        case [1, 7]:            return "Weekends"
        case []:                return "Never"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols   // ["Sun", "Mon", ...]
            return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }
}
