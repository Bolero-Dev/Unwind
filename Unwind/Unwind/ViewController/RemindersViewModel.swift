//
//  RemindersViewModel.swift
//  Unwind
//
//  Schedules / cancels the local notifications behind each `Reminder`.
//  One repeating `UNCalendarNotificationTrigger` is created per selected
//  weekday, so a reminder on Mon/Wed/Fri produces three weekly notifications.
//
//  Created by Leah Cluff on 4/10/23.
//

import Foundation
import UserNotifications
import os

enum ReminderScheduler {

    /// Ask for notification permission if we haven't already.
    /// Returns whether we're allowed to post notifications.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                Log.notifications.info("Notification authorization \(granted ? "granted" : "denied").")
                return granted
            } catch {
                Log.notifications.error("Authorization request failed: \(error.localizedDescription)")
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        default:    // .denied
            Log.notifications.info("Notifications previously denied; reminders won't fire.")
            return false
        }
    }

    /// Re-create the scheduled notifications for one reminder. Call this after
    /// adding, editing, or toggling a reminder. Removing-then-adding keeps the
    /// system in sync with whatever the reminder currently says.
    static func sync(_ reminder: Reminder) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: reminder))

        guard reminder.isEnabled, !reminder.weekdays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Unwind"
        content.body = reminder.label.isEmpty ? "Time to unwind." : reminder.label
        content.sound = .default

        for weekday in reminder.weekdays {
            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute
            components.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(reminder.id.uuidString)-\(weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    Log.notifications.error("Failed to schedule \(request.identifier): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Remove all notifications for a reminder (e.g. when it's deleted).
    static func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers(for: reminder))
    }

    /// Every identifier this reminder could own — one per weekday slot.
    private static func identifiers(for reminder: Reminder) -> [String] {
        (1...7).map { "\(reminder.id.uuidString)-\($0)" }
    }
}
