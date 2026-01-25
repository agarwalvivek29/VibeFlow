//
//  PermissionsStepView.swift
//  VibeFlow
//
//  Second step of onboarding - permissions setup
//

import SwiftUI

struct PermissionsStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var hasAccessibility = false
    @State private var hasMicrophone = false
    @State private var hasSpeechRecognition = false
    @State private var permissionCheckTimer: Timer?

    private var allPermissionsGranted: Bool {
        hasAccessibility && hasMicrophone && hasSpeechRecognition
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("VibeFlow needs a few permissions to work properly")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permission cards
            VStack(spacing: 12) {
                PermissionCard(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Monitor the Fn key globally",
                    granted: hasAccessibility,
                    grantAction: {
                        PermissionsHelper.requestAccessibilityPermissions()
                        recheckPermissionsDelayed()
                    },
                    openSettingsAction: PermissionsHelper.openAccessibilityPreferences
                )

                PermissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Record your voice for transcription",
                    granted: hasMicrophone,
                    grantAction: {
                        PermissionsHelper.requestMicrophonePermission()
                        recheckPermissionsDelayed()
                    },
                    openSettingsAction: PermissionsHelper.openMicrophonePreferences
                )

                PermissionCard(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Transcribe speech on-device",
                    granted: hasSpeechRecognition,
                    grantAction: {
                        Task {
                            await PermissionsHelper.requestSpeechRecognitionPermission()
                            recheckPermissionsDelayed()
                        }
                    },
                    openSettingsAction: PermissionsHelper.openSpeechRecognitionPreferences
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text(allPermissionsGranted ? "Continue" : "Continue Anyway")
                        .font(.headline)
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if !allPermissionsGranted {
                    Button(action: onSkip) {
                        Text("Skip for Now")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
                .frame(height: 40)
        }
        .padding()
        .onAppear {
            checkPermissions()
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkPermissions()
            }
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }

    private func checkPermissions() {
        hasAccessibility = PermissionsHelper.checkAccessibilityPermissions()
        hasMicrophone = PermissionsHelper.checkMicrophonePermission()
        hasSpeechRecognition = PermissionsHelper.checkSpeechRecognitionPermission()
    }

    private func recheckPermissionsDelayed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let grantAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(granted ? .green : .orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                HStack(spacing: 8) {
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
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    PermissionsStepView(onContinue: {}, onSkip: {})
}
