//
//  HistoryEntryRow.swift
//  VibeFlow
//
//  List row component for transcription history entries
//

import SwiftUI

struct HistoryEntryRow: View {
    let entry: TranscriptionEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.preview)
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(isSelected ? .white : .primary)

            HStack(spacing: 8) {
                Text(entry.relativeTimeString)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)

                if entry.usedLLMProcessing {
                    Label("LLM", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }

                Spacer()

                Text("\(entry.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        HistoryEntryRow(
            entry: TranscriptionEntry(
                rawTranscript: "Hello this is a test transcription with some words",
                processedText: "Hello, this is a test transcription with some words.",
                llmModel: "gpt-4o-mini",
                writingStyle: "Professional",
                usedLLMProcessing: true,
                wordCount: 9
            ),
            isSelected: false
        )
        HistoryEntryRow(
            entry: TranscriptionEntry(
                rawTranscript: "Another test",
                processedText: "Another test",
                timestamp: Date().addingTimeInterval(-3600),
                llmModel: "gpt-4o-mini",
                writingStyle: "Casual",
                usedLLMProcessing: false,
                wordCount: 2
            ),
            isSelected: true
        )
    }
    .padding()
    .frame(width: 300)
}
