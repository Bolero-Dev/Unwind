//
//  UnwindApp.swift
//  Unwind
//
//  App entry point. Builds the SwiftData model container, falling back to an
//  in-memory store (rather than crashing) if the on-disk store can't be opened.
//

import SwiftUI
import SwiftData
import os

@main
struct UnwindApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: JournalEntry.self, Reminder.self)
        } catch {
            // A corrupt / unreadable store shouldn't take the whole app down —
            // log it and keep running on an in-memory store for this launch.
            Log.data.error("Persistent store unavailable (\(error.localizedDescription)); using in-memory store.")
            do {
                container = try ModelContainer(
                    for: JournalEntry.self, Reminder.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("Could not create an in-memory model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
