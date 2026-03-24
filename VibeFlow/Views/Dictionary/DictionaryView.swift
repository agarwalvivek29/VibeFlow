//
//  DictionaryView.swift
//  VibeFlow
//
//  Custom dictionary management for speech recognition
//

import SwiftUI
import SwiftData

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictionaryEntry.createdAt, order: .reverse) private var entries: [DictionaryEntry]
    @State private var searchText = ""
    @State private var isAddingTerm = false
    @State private var newTermText = ""

    private let brandColor = Color(red: 0.357, green: 0.310, blue: 0.914)

    private var filteredEntries: [DictionaryEntry] {
        guard !searchText.isEmpty else { return entries }
        let lowercased = searchText.lowercased()
        return entries.filter { $0.term.lowercased().contains(lowercased) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
                .padding(.top, 16)

            if isAddingTerm {
                addTermRow
                Divider()
                    .padding(.horizontal, 32)
            }

            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                termsList
            }
        }
        .background(Color.white)
        .navigationTitle("")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Dictionary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Add technical terms, names, and jargon for better recognition")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                isAddingTerm = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(brandColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField("Search terms...", text: $searchText)
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
        .padding(.top, 8)
    }

    // MARK: - Add Term

    private var addTermRow: some View {
        HStack(spacing: 12) {
            TextField("Enter a new term...", text: $newTermText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { addTerm() }

            Button("Add") { addTerm() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(newTermText.isEmpty ? .secondary : brandColor)
                .disabled(newTermText.isEmpty)

            Button("Cancel") {
                newTermText = ""
                isAddingTerm = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(brandColor.opacity(0.04))
    }

    // MARK: - Terms List

    private var termsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredEntries) { entry in
                    DictionaryRow(entry: entry, brandColor: brandColor) {
                        deleteEntry(entry)
                    }
                    Divider()
                        .padding(.horizontal, 32)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "character.book.closed" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No Terms Yet" : "No Results")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Text(searchText.isEmpty
                 ? "Add technical terms, names, and jargon to improve transcription accuracy."
                 : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addTerm() {
        let trimmed = newTermText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = DictionaryEntry(
            id: UUID(),
            term: trimmed,
            category: nil,
            isEnabled: true,
            createdAt: Date()
        )
        modelContext.insert(entry)
        newTermText = ""
        isAddingTerm = false
    }

    private func deleteEntry(_ entry: DictionaryEntry) {
        modelContext.delete(entry)
    }
}

// MARK: - Row View

struct DictionaryRow: View {
    @Bindable var entry: DictionaryEntry
    let brandColor: Color
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.term)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                if let category = entry.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(brandColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(brandColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Toggle("", isOn: $entry.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(Color.white)
        .alert("Delete Term?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("\"\(entry.term)\" will be permanently deleted.")
        }
    }
}

#Preview {
    DictionaryView()
        .modelContainer(for: DictionaryEntry.self, inMemory: true)
        .frame(width: 740, height: 650)
}
