//
//  ModelManagementView.swift
//  VibeFlow
//
//  Model download and cache management UI
//

import SwiftUI

struct ModelManagementView: View {
    @ObservedObject var downloadManager: ModelDownloadManager

    private let brandColor = Color(red: 0.357, green: 0.310, blue: 0.914)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(title: "Speech Recognition (Whisper)")

            ForEach(ModelDownloadManager.WhisperModelSize.allCases, id: \.self) { size in
                ModelRow(
                    name: "Whisper \(size.rawValue.capitalized)",
                    detail: size.displayName,
                    state: downloadManager.whisperStates[size] ?? .notDownloaded,
                    brandColor: brandColor,
                    onDownload: {
                        Task { await downloadManager.downloadWhisperModel(size: size) }
                    },
                    onDelete: {
                        try? downloadManager.deleteModel(.whisper(size))
                    }
                )
            }

            Divider()
                .padding(.vertical, 4)

            SectionHeader(title: "Text Cleanup (Qwen SLM)")

            ModelRow(
                name: "Qwen 2.5 0.5B",
                detail: "Downloaded on first use by MLX",
                state: downloadManager.slmState,
                brandColor: brandColor,
                onDownload: {
                    Task { await downloadManager.downloadSLMModel() }
                },
                onDelete: {
                    try? downloadManager.deleteModel(.slm)
                }
            )
        }
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
    }
}

// MARK: - Model row

private struct ModelRow: View {
    let name: String
    let detail: String
    let state: ModelDownloadManager.DownloadState
    let brandColor: Color
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            stateView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .alert("Delete Model", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will remove the downloaded model file. You can re-download it later.")
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch state {
        case .notDownloaded:
            Button(action: onDownload) {
                Text("Download")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(brandColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .tint(brandColor)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

        case .downloaded:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)

                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

        case .error(let message):
            HStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .frame(maxWidth: 120)

                Button(action: onDownload) {
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(brandColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
