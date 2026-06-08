//
//  JournalEntry.swift
//  Unwind
//
//  SwiftData model. Replaces the old `JournalModel` (Codable class).
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
