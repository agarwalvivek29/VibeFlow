//
//  HistoryView.swift
//  VibeFlow
//
//  Minimal transcription history list
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionEntry.timestamp, order: .reverse) private var entries: [TranscriptionEntry]
    @State private var searchText = ""
    @State private var copiedEntryId: UUID?
    @State private var selectedEntry: TranscriptionEntry?

    private var filteredEntries: [TranscriptionEntry] {
        guard !searchText.isEmpty else { return entries }
        let lowercased = searchText.lowercased()
        return entries.filter { entry in
            entry.rawTranscript.lowercased().contains(lowercased) ||
            entry.processedText.lowercased().contains(lowercased)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar at top
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Divider()
                .padding(.top, 16)

            // Transcript list
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            Button { selectedEntry = entry } label: {
                                TranscriptRow(
                                    entry: entry,
                                    isCopied: copiedEntryId == entry.id,
                                    onCopy: {
                                        copyToClipboard(entry.processedText)
                                        copiedEntryId = entry.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            if copiedEntryId == entry.id { copiedEntryId = nil }
                                        }
                                    },
                                    onDelete: { deleteEntry(entry) }
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.horizontal, 32)
                        }
                    }
                    .padding(.top, 12)
                }
                .sheet(item: $selectedEntry) { entry in
                    HistoryDetailView(entry: entry, onDelete: {
                        deleteEntry(entry)
                        selectedEntry = nil
                    })
                    .frame(minWidth: 480, minHeight: 360)
                }
            }
        }
        .background(Color.white)
        .navigationTitle("")
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No History Yet" : "No Results")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Text(searchText.isEmpty
                 ? "Your transcriptions will appear here after you record them."
                 : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }

    private func deleteEntry(_ entry: TranscriptionEntry) {
        modelContext.delete(entry)
    }
}

struct TranscriptRow: View {
    let entry: TranscriptionEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Timestamp
                Text(entry.timestamp, style: .relative)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Transcript preview
                Text(entry.processedText)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(5)
                    .textSelection(.enabled)

                // Metadata
                HStack(spacing: 12) {
                    if entry.usedLLMProcessing {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("AI Enhanced")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(red: 0.357, green: 0.310, blue: 0.914))
                    }

                    Text("\(entry.wordCount) words")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let wpm = entry.wordsPerMinute {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(wpm) wpm")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(entry.writingStyle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 12)

            // Actions - always visible as small icons
            HStack(spacing: 4) {
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(isCopied ? .green : .secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Color.white)
        .alert("Delete Transcription?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This transcription will be permanently deleted.")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
        .frame(width: 1000, height: 650)
}
