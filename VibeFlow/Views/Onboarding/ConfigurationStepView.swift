//
//  ConfigurationStepView.swift
//  VibeFlow
//
//  Third step of onboarding - configuration
//

import SwiftUI

struct ConfigurationStepView: View {
    let onContinue: () -> Void

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Configure VibeFlow")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Customize how your transcriptions are processed")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Settings
            VStack(alignment: .leading, spacing: 24) {
                // LLM Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.useLLMProcessing) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.purple)
                            Text("AI Text Enhancement")
                                .font(.headline)
                        }
                    }
                    .toggleStyle(.switch)

                    Text(settings.useLLMProcessing
                         ? "Transcriptions will be cleaned up by an LLM before pasting"
                         : "Raw transcription will be pasted directly (faster)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }

                // LLM Configuration (shown when enabled)
                if settings.useLLMProcessing {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LiteLLM Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("http://127.0.0.1:4000", text: $settings.liteLLMBaseURL)
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
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Writing Style
                VStack(alignment: .leading, spacing: 8) {
                    Text("Writing Style")
                        .font(.headline)

                    Picker("", selection: $settings.writingStyle) {
                        ForEach(AppSettings.WritingStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(settings.writingStyle.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .opacity(settings.useLLMProcessing ? 1.0 : 0.5)
                .disabled(!settings.useLLMProcessing)
            }
            .padding(.horizontal, 60)
            .animation(.easeInOut, value: settings.useLLMProcessing)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}

#Preview {
    ConfigurationStepView(onContinue: {})
        .environmentObject(AppSettings())
}
