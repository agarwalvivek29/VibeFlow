//
//  HistoryDetailView.swift
//  VibeFlow
//
//  Detail panel for viewing and interacting with transcription entries
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct HistoryDetailView: View {
    let entry: TranscriptionEntry
    let onDelete: () -> Void

    @State private var showingRaw = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with actions
            HStack {
                Text(entry.timestamp, style: .date)
                    .font(.headline)
                Text("at")
                    .foregroundStyle(.secondary)
                Text(entry.timestamp, style: .time)
                    .font(.headline)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Content toggle
            if entry.usedLLMProcessing && entry.rawTranscript != entry.processedText {
                Picker("View", selection: $showingRaw) {
                    Text("Processed").tag(false)
                    Text("Raw").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
            }

            // Transcription text
            ScrollView {
                Text(showingRaw ? entry.rawTranscript : entry.processedText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Divider()

            // Settings snapshot
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings Used")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("Model:")
                            .foregroundStyle(.secondary)
                        Text(entry.llmModel)
                    }
                    GridRow {
                        Text("Style:")
                            .foregroundStyle(.secondary)
                        Text(entry.writingStyle)
                    }
                    GridRow {
                        Text("LLM Processing:")
                            .foregroundStyle(.secondary)
                        Text(entry.usedLLMProcessing ? "Yes" : "No")
                    }
                    GridRow {
                        Text("Word Count:")
                            .foregroundStyle(.secondary)
                        Text("\(entry.wordCount)")
                    }
                    GridRow {
                        Text("Speed:")
                            .foregroundStyle(.secondary)
                        Text(entry.wordsPerMinute.map { "\($0) wpm" } ?? "—")
                    }
                    GridRow {
                        Text("Duration:")
                            .foregroundStyle(.secondary)
                        Text(entry.durationSeconds > 0 ? "\(Int(entry.durationSeconds))s" : "—")
                    }
                }
                .font(.callout)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This transcription will be permanently deleted.")
        }
    }

    private func copyToClipboard() {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(showingRaw ? entry.rawTranscript : entry.processedText, forType: .string)
        #endif
    }
}

#Preview {
    HistoryDetailView(
        entry: TranscriptionEntry(
            rawTranscript: "um hello this is uh a test transcription with some words you know",
            processedText: "Hello, this is a test transcription with some words.",
            llmModel: "gpt-4o-mini",
            writingStyle: "Professional",
            usedLLMProcessing: true,
            wordCount: 9
        ),
        onDelete: {}
    )
    .frame(width: 500, height: 400)
}
