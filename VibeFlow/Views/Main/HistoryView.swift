//
//  HistoryView.swift
//  VibeFlow
//
//  Transcription history view with master-detail layout
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionEntry.timestamp, order: .reverse) private var entries: [TranscriptionEntry]
    @State private var searchText = ""
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
        HSplitView {
            // Master list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search transcriptions...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()

                Divider()

                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    List(selection: $selectedEntry) {
                        ForEach(filteredEntries) { entry in
                            HistoryEntryRow(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id
                            )
                            .tag(entry)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)

            // Detail panel
            if let entry = selectedEntry {
                HistoryDetailView(entry: entry) {
                    deleteEntry(entry)
                }
            } else {
                noSelectionView
            }
        }
        .navigationTitle("History")
        .onChange(of: filteredEntries) {
            // Clear selection if selected entry is no longer in filtered results
            if let selected = selectedEntry,
               !filteredEntries.contains(where: { $0.id == selected.id }) {
                selectedEntry = nil
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "clock" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No History Yet" : "No Results")
                .font(.headline)
            Text(searchText.isEmpty
                 ? "Your transcriptions will appear here after you record them."
                 : "Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a Transcription")
                .font(.headline)
            Text("Choose an entry from the list to view its details.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteEntry(_ entry: TranscriptionEntry) {
        modelContext.delete(entry)
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
        .frame(width: 800, height: 500)
}
