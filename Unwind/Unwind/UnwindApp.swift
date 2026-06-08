////
//  UnwindApp.swift
//  Unwind
//
//  App entry point. Registers the SwiftData model container.
//
//  NOTE: If you ALREADY have an @main App struct in your project,
//  do NOT add this file (two @main = compile error). Instead, just add
//  the `.modelContainer(...)` line below to your existing WindowGroup.
//

import SwiftUI
import SwiftData

@main
struct UnwindApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [JournalEntry.self, Reminder.self])
    }
}
