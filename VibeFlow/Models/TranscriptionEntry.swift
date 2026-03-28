//
//  TranscriptionEntry.swift
//  VibeFlow
//
//  Data model for transcription history entries
//

import Foundation
import SwiftData

@Model
final class TranscriptionEntry {
    @Attribute(.unique) var id: UUID
    var rawTranscript: String
    var processedText: String
    var timestamp: Date
    var llmModel: String
    var writingStyle: String
    var usedLLMProcessing: Bool
    var wordCount: Int
    var durationSeconds: Double

    init(
        id: UUID = UUID(),
        rawTranscript: String,
        processedText: String,
        timestamp: Date = Date(),
        llmModel: String,
        writingStyle: String,
        usedLLMProcessing: Bool,
        wordCount: Int,
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.processedText = processedText
        self.timestamp = timestamp
        self.llmModel = llmModel
        self.writingStyle = writingStyle
        self.usedLLMProcessing = usedLLMProcessing
        self.wordCount = wordCount
        self.durationSeconds = durationSeconds
    }
}

extension TranscriptionEntry {
    var preview: String {
        let text = processedText.isEmpty ? rawTranscript : processedText
        let maxLength = 80
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    var wordsPerMinute: Int? {
        guard durationSeconds > 5, wordCount > 0 else { return nil }
        return Int((Double(wordCount) / durationSeconds) * 60)
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var displayText: String {
        processedText.isEmpty ? rawTranscript : processedText
    }
}
