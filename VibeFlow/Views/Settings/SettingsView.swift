//
//  SettingsView.swift
//  VibeFlow
//
//  Minimal settings
//

import SwiftUI
#if os(macOS)
import Carbon.HIToolbox
#endif

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Recording Hotkey
                SettingsSection(title: "Recording Hotkey") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(RecordingKeyPreset.allCases, id: \.self) { preset in
                            RadioRow(
                                title: preset.rawValue,
                                subtitle: preset.description,
                                isSelected: settings.recordingKeyPreset == preset
                            ) {
                                settings.recordingKeyPreset = preset
                            }
                        }

                        // Custom key capture field
                        if settings.recordingKeyPreset == .custom {
                            KeyCaptureField(
                                label: "Press a key combination",
                                binding: settings.customRecordingKey
                            ) { newBinding in
                                settings.customRecordingKey = newBinding
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                // Speech Engine
                SettingsSection(title: "Speech Engine") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Speech Engine", selection: $settings.speechEngine) {
                            Text("Apple Speech").tag(AppSettings.SpeechEngine.apple)
                            Text("Whisper").tag(AppSettings.SpeechEngine.whisper)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        if settings.speechEngine == .whisper {
                            Picker("Model Size", selection: $settings.whisperModelSize) {
                                Text("Tiny").tag(AppSettings.WhisperModelSize.tiny)
                                Text("Base").tag(AppSettings.WhisperModelSize.base)
                                Text("Small").tag(AppSettings.WhisperModelSize.small)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        Text("Apple Speech uses on-device recognition. Whisper runs locally for potentially better accuracy.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Text Cleanup
                SettingsSection(title: "Text Cleanup") {
                    VStack(alignment: .leading, spacing: 12) {
                        ToggleRow(title: "Enable AI Text Enhancement", isOn: $settings.useLLMProcessing)

                        if settings.useLLMProcessing {
                            Divider()

                            Picker("Cleanup Engine", selection: $settings.textCleanupEngine) {
                                Text("Local SLM").tag(AppSettings.TextCleanupEngine.localSLM)
                                Text("Remote LLM").tag(AppSettings.TextCleanupEngine.remoteLLM)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            if settings.textCleanupEngine == .remoteLLM {
                                LabeledField(label: "Base URL", placeholder: "http://127.0.0.1:4000", text: $settings.liteLLMBaseURL)
                                LabeledField(label: "Model", placeholder: "gpt-4o-mini", text: $settings.llmModel)
                            } else {
                                Text("Uses Qwen 2.5 (0.5B) running locally on your Mac. No internet required.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Writing Style")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                ForEach(AppSettings.WritingStyle.allCases, id: \.self) { style in
                                    RadioRow(
                                        title: style.rawValue,
                                        subtitle: style.description,
                                        isSelected: settings.writingStyle == style
                                    ) {
                                        settings.writingStyle = style
                                    }
                                }
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Formality")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Picker("Formality", selection: $settings.formality) {
                                    ForEach(AppSettings.Formality.allCases, id: \.self) { level in
                                        Text(level.rawValue).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }

                            Divider()

                            ToggleRow(title: "Remove filler words", isOn: $settings.removeFiller)
                            ToggleRow(title: "Auto-format punctuation & capitalization", isOn: $settings.autoFormat)
                        }
                    }
                }

                // Custom Dictionary
                SettingsSection(title: "Custom Dictionary") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add technical terms, names, and jargon to improve recognition accuracy.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text("Manage your dictionary from the Dictionary tab in the sidebar.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.357, green: 0.310, blue: 0.914))
                    }
                }

                // Post Transcription
                SettingsSection(title: "After Transcription") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(PostTranscriptionAction.allCases, id: \.self) { action in
                            RadioRow(
                                title: action.rawValue,
                                subtitle: action.description,
                                isSelected: settings.postTranscriptionAction == action
                            ) {
                                settings.postTranscriptionAction = action
                            }
                        }

                        if settings.postTranscriptionAction == .customKeyCombo {
                            KeyCaptureField(
                                label: "Press a key combination",
                                binding: settings.customPostTranscriptionKey
                            ) { newBinding in
                                settings.customPostTranscriptionKey = newBinding
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                // Permissions
                PermissionsSection()

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
        }
        .background(Color.white)
        .navigationTitle("")
    }
}

// MARK: - Section wrapper

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            content
        }
    }
}

// MARK: - Toggle row

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

// MARK: - Radio row

private struct RadioRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(isSelected ? Color(red: 0.357, green: 0.310, blue: 0.914) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 5 : 1.5)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Labeled text field

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Key capture field

private struct KeyCaptureField: View {
    let label: String
    let binding: KeyBinding?
    let onCapture: (KeyBinding) -> Void

    @State private var isCapturing = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button(action: {
                startCapturing()
            }) {
                HStack {
                    if isCapturing {
                        Text("Press any key...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.357, green: 0.310, blue: 0.914))
                    } else if let binding = binding {
                        Text(binding.displayString)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    } else {
                        Text("Click to set")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isCapturing {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.357, green: 0.310, blue: 0.914))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isCapturing ? Color(red: 0.357, green: 0.310, blue: 0.914).opacity(0.06) : Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCapturing ? Color(red: 0.357, green: 0.310, blue: 0.914).opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func startCapturing() {
        #if os(macOS)
        isCapturing = true

        // Listen for key events
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                let captured = KeyBinding(
                    keyCode: event.keyCode,
                    modifiers: event.modifierFlags.intersection([.command, .option, .control, .shift, .function]).rawValue,
                    isModifierOnly: false
                )
                onCapture(captured)
                stopCapturing()
                return nil // consume the event
            } else if event.type == .flagsChanged {
                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
                if !flags.isEmpty {
                    let captured = KeyBinding(
                        keyCode: event.keyCode,
                        modifiers: flags.rawValue,
                        isModifierOnly: true
                    )
                    onCapture(captured)
                    stopCapturing()
                    return nil
                }
            }
            return event
        }
        #endif
    }

    private func stopCapturing() {
        #if os(macOS)
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isCapturing = false
        #endif
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(granted ? Color(red: 0.357, green: 0.310, blue: 0.914) : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(granted ? Color(red: 0.357, green: 0.310, blue: 0.914) : Color.secondary.opacity(0.2))
                        .frame(width: 40, height: 22)
                        .animation(.easeInOut(duration: 0.2), value: granted)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .offset(x: granted ? 9 : -9)
                        .animation(.easeInOut(duration: 0.2), value: granted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(granted)
    }
}

// MARK: - Permissions section

private struct PermissionsSection: View {
    @State private var hasAccessibilityPermission = false
    @State private var hasMicrophonePermission = false
    @State private var hasSpeechRecognitionPermission = false
    @State private var permissionCheckTimer: Timer?

    var body: some View {
        SettingsSection(title: "Permissions") {
            VStack(spacing: 8) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    granted: hasMicrophonePermission
                ) {
                    PermissionsHelper.requestMicrophonePermission()
                    recheckPermissions()
                }

                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    granted: hasAccessibilityPermission
                ) {
                    PermissionsHelper.requestAccessibilityPermissions()
                    recheckPermissions()
                }

                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    granted: hasSpeechRecognitionPermission
                ) {
                    Task {
                        await PermissionsHelper.requestSpeechRecognitionPermission()
                        recheckPermissions()
                    }
                }
            }
        }
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

    private func checkPermissions() {
        hasAccessibilityPermission = PermissionsHelper.checkAccessibilityPermissions()
        hasMicrophonePermission = PermissionsHelper.checkMicrophonePermission()
        hasSpeechRecognitionPermission = PermissionsHelper.checkSpeechRecognitionPermission()
    }

    private func recheckPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkPermissions()
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}
