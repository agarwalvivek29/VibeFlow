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
    var rawTranscript: String
    var processedText: String
    var timestamp: Date
    var llmModel: String
    var writingStyle: String
    var formality: String
    var usedLLMProcessing: Bool
    var wordCount: Int

    init(
        rawTranscript: String,
        processedText: String,
        timestamp: Date = Date(),
        llmModel: String,
        writingStyle: String,
        formality: String,
        usedLLMProcessing: Bool,
        wordCount: Int
    ) {
        self.rawTranscript = rawTranscript
        self.processedText = processedText
        self.timestamp = timestamp
        self.llmModel = llmModel
        self.writingStyle = writingStyle
        self.formality = formality
        self.usedLLMProcessing = usedLLMProcessing
        self.wordCount = wordCount
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

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var displayText: String {
        processedText.isEmpty ? rawTranscript : processedText
    }
}
