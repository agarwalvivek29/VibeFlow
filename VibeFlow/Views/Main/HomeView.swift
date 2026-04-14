//
//  HomeView.swift
//  VibeFlow
//
//  Dashboard view with status, stats, and recent transcriptions
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct DashboardView: View {
    @Binding var selectedNavigation: NavigationItem?
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionEntry.timestamp, order: .reverse) private var entries: [TranscriptionEntry]
    @State private var copiedEntryId: UUID?
    @State private var hasAccessibilityPermission = false
    @State private var hasMicrophonePermission = false
    @State private var hasSpeechRecognitionPermission = false

    private var recentEntries: [TranscriptionEntry] {
        Array(entries.prefix(5))
    }

    private var hasModelLoadFailure: Bool {
        if case .failed = controller.speechEngineState { return true }
        if case .failed = controller.textProcessorState { return true }
        return false
    }

    private var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Permissions banner (only when missing)
                if !allPermissionsGranted {
                    permissionsBanner
                }

                // Status card
                statusCard

                // Quick stats
                statsRow

                // Recent transcriptions
                recentTranscriptionsSection

                // Hotkey hint
                hotkeyHint
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("")
        .onAppear { checkPermissions() }
    }

    // MARK: - Permissions Banner

    private var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasMicrophonePermission && hasSpeechRecognitionPermission
    }

    private var permissionsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Setup Required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Some permissions are missing. Grant them in Settings to start using VibeFlow.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { selectedNavigation = .settings }) {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func checkPermissions() {
        hasAccessibilityPermission = PermissionsHelper.checkAccessibilityPermissions()
        hasMicrophonePermission = PermissionsHelper.checkMicrophonePermission()
        hasSpeechRecognitionPermission = PermissionsHelper.checkSpeechRecognitionPermission()
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Hotkey: \(settings.activeRecordingKey.displayString)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if controller.isRecording {
                Button(action: {
                    Task { await controller.testStopRecording() }
                }) {
                    Text("Stop")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Stats

    private var avgWPM: Int {
        let valid = entries.compactMap(\.wordsPerMinute)
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / valid.count
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatBox(label: "Transcriptions", value: "\(entries.count)")
            StatBox(label: "Words", value: "\(totalWords)")
            StatBox(label: "Avg WPM", value: avgWPM > 0 ? "\(avgWPM)" : "—")
        }
    }

    // MARK: - Recent Transcriptions

    private var recentTranscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transcriptions")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if recentEntries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No transcriptions yet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(recentEntries) { entry in
                        TranscriptRow(
                            entry: entry,
                            isCopied: copiedEntryId == entry.id,
                            onCopy: {
                                copyToClipboard(entry.displayText)
                                copiedEntryId = entry.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedEntryId == entry.id {
                                        copiedEntryId = nil
                                    }
                                }
                            },
                            onDelete: {
                                modelContext.delete(entry)
                            }
                        )
                        if entry.id != recentEntries.last?.id {
                            Divider()
                                .padding(.horizontal, 32)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Hotkey Hint

    private var hotkeyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.system(size: 11))
            Text("Press \(settings.activeRecordingKey.displayString) to start recording")
                .font(.system(size: 12))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private var statusText: String {
        if controller.isRecording {
            return "Recording"
        } else if controller.isProcessing {
            return "Processing…"
        } else if hasModelLoadFailure {
            return "Model Error"
        } else if !allPermissionsGranted {
            return "Setup Required"
        } else {
            return "Ready"
        }
    }

    private var statusColor: Color {
        if controller.isRecording {
            return .red
        } else if controller.isProcessing {
            return Color(red: 0.357, green: 0.310, blue: 0.914)
        } else if hasModelLoadFailure {
            return .red
        } else if !allPermissionsGranted {
            return .orange
        } else {
            return Color(red: 0.357, green: 0.310, blue: 0.914)
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

#Preview {
    DashboardView(selectedNavigation: .constant(.dashboard))
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            speechEngine: AppleSpeechEngine(),
            textProcessor: nil,
            settings: AppSettings()
        ))
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
