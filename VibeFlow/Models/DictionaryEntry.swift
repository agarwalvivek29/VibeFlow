//
//  DictionaryEntry.swift
//  VibeFlow
//
//  Data model for custom dictionary vocabulary terms
//

import Foundation
import SwiftData

@Model
final class DictionaryEntry {
    @Attribute(.unique) var id: UUID
    var term: String
    var category: String?
    var isEnabled: Bool
    var createdAt: Date

    init(term: String, category: String? = nil) {
        self.id = UUID()
        self.term = term
        self.category = category
        self.isEnabled = true
        self.createdAt = Date()
    }
}
