//
//  SettingsView.swift
//  VibeFlow
//
//  Settings UI for configuring VibeFlow
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    private var recordingKeyDisplayName: String {
        settings.activeRecordingKey.displayString
    }

    private var postActionDescription: String {
        switch settings.postTranscriptionAction {
        case .autoPaste:
            return " and paste"
        case .clipboardOnly:
            return " (copied to clipboard)"
        case .customKeyCombo:
            if let key = settings.customPostTranscriptionKey {
                return " and send \(key.displayString)"
            }
            return " (set custom key)"
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Processing Mode").font(.headline)) {
                Toggle("Use LLM Processing", isOn: $settings.useLLMProcessing)

                if settings.useLLMProcessing {
                    Text("Transcribed speech will be cleaned up by an LLM before pasting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Direct paste mode: Raw transcription pasted immediately (faster)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("LiteLLM Configuration").font(.headline)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("http://127.0.0.1:4000", text: $settings.liteLLMBaseURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Leave blank if not required", text: $settings.liteLLMApiKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("gpt-4o-mini", text: $settings.llmModel)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .opacity(settings.useLLMProcessing ? 1.0 : 0.5)
            .disabled(!settings.useLLMProcessing)

            Section(header: Text("Writing Preferences").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Writing Style")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $settings.writingStyle) {
                        ForEach(AppSettings.WritingStyle.allCases, id: \.self) { style in
                            VStack(alignment: .leading) {
                                Text(style.rawValue)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Formality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $settings.formality) {
                        ForEach(AppSettings.Formality.allCases, id: \.self) { formality in
                            Text(formality.rawValue).tag(formality)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Remove filler words (um, uh, like, etc.)", isOn: $settings.removeFiller)
                Toggle("Auto-format punctuation and capitalization", isOn: $settings.autoFormat)
            }
            .opacity(settings.useLLMProcessing ? 1.0 : 0.5)
            .disabled(!settings.useLLMProcessing)

            Section(header: Text("Recording Key").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Trigger Key", selection: $settings.recordingKeyPreset) {
                        ForEach(RecordingKeyPreset.allCases, id: \.self) { preset in
                            VStack(alignment: .leading) {
                                Text(preset.rawValue)
                            }
                            .tag(preset)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(settings.recordingKeyPreset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if settings.recordingKeyPreset == .custom {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            KeyCaptureView(keyBinding: $settings.customRecordingKey)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Section(header: Text("After Transcription").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Action", selection: $settings.postTranscriptionAction) {
                        ForEach(PostTranscriptionAction.allCases, id: \.self) { action in
                            VStack(alignment: .leading) {
                                Text(action.rawValue)
                            }
                            .tag(action)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(settings.postTranscriptionAction.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if settings.postTranscriptionAction == .customKeyCombo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Key Combo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            KeyCaptureView(keyBinding: $settings.customPostTranscriptionKey)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Section(header: Text("How to Use").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("1.")
                            .fontWeight(.bold)
                        Text("Press and hold \(recordingKeyDisplayName) to start recording")
                    }
                    HStack(alignment: .top) {
                        Text("2.")
                            .fontWeight(.bold)
                        Text("Speak your text naturally")
                    }
                    HStack(alignment: .top) {
                        Text("3.")
                            .fontWeight(.bold)
                        Text("Release \(recordingKeyDisplayName) to transcribe\(postActionDescription)")
                    }
                }
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}
