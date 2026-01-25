//
//  HomeView.swift
//  VibeFlow
//
//  Home dashboard view
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController
    @State private var hasAccessibilityPermission = false
    @State private var hasMicrophonePermission = false
    @State private var hasSpeechRecognitionPermission = false
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Brand banner
                BrandHeaderView(style: .banner)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                // Quick stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        StatCard(
                            icon: settings.useLLMProcessing ? "brain" : "bolt.fill",
                            value: settings.useLLMProcessing ? "AI Processing" : "Direct Paste",
                            label: "Processing Mode",
                            iconColor: settings.useLLMProcessing ? .purple : .yellow
                        )

                        StatCard(
                            icon: statusIcon,
                            value: statusText,
                            label: "Status",
                            iconColor: statusColor
                        )
                    }
                }

                // Permissions section (if any missing)
                if !hasAccessibilityPermission || !hasMicrophonePermission || !hasSpeechRecognitionPermission {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions Required")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            if !hasAccessibilityPermission {
                                PermissionRow(
                                    icon: "hand.raised.fill",
                                    title: "Accessibility",
                                    description: "Required for global hotkey",
                                    granted: false,
                                    grantAction: {
                                        PermissionsHelper.requestAccessibilityPermissions()
                                        recheckPermissions()
                                    },
                                    openSettingsAction: PermissionsHelper.openAccessibilityPreferences
                                )
                            }

                            if !hasMicrophonePermission {
                                PermissionRow(
                                    icon: "mic.fill",
                                    title: "Microphone",
                                    description: "Required for voice recording",
                                    granted: false,
                                    grantAction: {
                                        PermissionsHelper.requestMicrophonePermission()
                                        recheckPermissions()
                                    },
                                    openSettingsAction: PermissionsHelper.openMicrophonePreferences
                                )
                            }

                            if !hasSpeechRecognitionPermission {
                                PermissionRow(
                                    icon: "waveform",
                                    title: "Speech Recognition",
                                    description: "Required for transcription",
                                    granted: false,
                                    grantAction: {
                                        Task {
                                            await PermissionsHelper.requestSpeechRecognitionPermission()
                                            recheckPermissions()
                                        }
                                    },
                                    openSettingsAction: PermissionsHelper.openSpeechRecognitionPreferences
                                )
                            }
                        }
                    }
                }

                // How to use section
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Use")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        InstructionRow(step: "1", text: "Press and hold the Fn key to start recording")
                        InstructionRow(step: "2", text: "Speak naturally into your microphone")
                        InstructionRow(step: "3", text: "Release the Fn key to transcribe and paste")
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }

                // Test button for debugging
                VStack(alignment: .leading, spacing: 12) {
                    Text("Testing")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            controller.testStartRecording()
                        } label: {
                            Label("Start Recording", systemImage: "mic.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isRecording)

                        if controller.isRecording {
                            Button {
                                Task {
                                    await controller.testStopRecording()
                                }
                            } label: {
                                Label("Stop Recording", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text("Use Right Command key as a hotkey fallback for testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Home")
        .onAppear {
            checkPermissions()
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                checkPermissions()
            }
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    // MARK: - Status Computed Properties

    private var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasMicrophonePermission && hasSpeechRecognitionPermission
    }

    private var statusIcon: String {
        if controller.isRecording {
            return "mic.fill"
        } else if !allPermissionsGranted {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if controller.isRecording {
            return "Recording..."
        } else if !allPermissionsGranted {
            return "Setup Required"
        } else {
            return "Ready"
        }
    }

    private var statusColor: Color {
        if controller.isRecording {
            return .red
        } else if !allPermissionsGranted {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Permission Helpers

    private func checkPermissions() {
        let newAccessibility = PermissionsHelper.checkAccessibilityPermissions()
        let newMicrophone = PermissionsHelper.checkMicrophonePermission()
        let newSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

        hasAccessibilityPermission = newAccessibility
        hasMicrophonePermission = newMicrophone
        hasSpeechRecognitionPermission = newSpeech
    }

    private func recheckPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

// MARK: - Supporting Views

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let grantAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Grant") {
                grantAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Settings") {
                openSettingsAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InstructionRow: View {
    let step: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.headline)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)),
            settings: AppSettings()
        ))
}
