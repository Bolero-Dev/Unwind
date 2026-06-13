//
//  JournalEntry.swift
//  Unwind
//
//  SwiftData model for a single journal entry.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var title: String
    var body: String
    var createdAt: Date

    init(title: String = "", body: String = "", createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
