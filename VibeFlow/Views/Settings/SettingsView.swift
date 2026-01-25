//
//  SettingsView.swift
//  VibeFlow
//
//  Settings UI for configuring VibeFlow
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

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

            Section(header: Text("How to Use").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("1.")
                            .fontWeight(.bold)
                        Text("Press and hold Fn key to start recording")
                    }
                    HStack(alignment: .top) {
                        Text("2.")
                            .fontWeight(.bold)
                        Text("Speak your text naturally")
                    }
                    HStack(alignment: .top) {
                        Text("3.")
                            .fontWeight(.bold)
                        Text("Release Fn key to transcribe and paste")
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
