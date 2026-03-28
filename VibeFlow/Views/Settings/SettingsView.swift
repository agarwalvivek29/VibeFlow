//
//  SettingsView.swift
//  VibeFlow
//
//  Settings with draft-save pattern: changes are local until Save is pressed.
//  Pressing Save rebuilds engines behind a loading overlay.
//  Navigating away with unsaved changes shows a discard confirmation.
//

import SwiftUI
#if os(macOS)
import Carbon.HIToolbox
#endif

// MARK: - Settings Draft

/// Local snapshot of all settings fields. Edited freely; applied to AppSettings only on Save.
private struct SettingsDraft {
    var speechEngine: AppSettings.SpeechEngine
    var whisperModelSize: AppSettings.WhisperModelSize
    var useLLMProcessing: Bool
    var textCleanupEngine: AppSettings.TextCleanupEngine
    var liteLLMBaseURL: String
    var liteLLMApiKey: String
    var llmModel: String
    var writingStyle: AppSettings.WritingStyle
    var formality: AppSettings.Formality
    var removeFiller: Bool
    var autoFormat: Bool
    var recordingKeyPreset: RecordingKeyPreset
    var customRecordingKey: KeyBinding?
    var postTranscriptionAction: PostTranscriptionAction
    var customPostTranscriptionKey: KeyBinding?

    init(from settings: AppSettings) {
        speechEngine = settings.speechEngine
        whisperModelSize = settings.whisperModelSize
        useLLMProcessing = settings.useLLMProcessing
        textCleanupEngine = settings.textCleanupEngine
        liteLLMBaseURL = settings.liteLLMBaseURL
        liteLLMApiKey = settings.liteLLMApiKey
        llmModel = settings.llmModel
        writingStyle = settings.writingStyle
        formality = settings.formality
        removeFiller = settings.removeFiller
        autoFormat = settings.autoFormat
        recordingKeyPreset = settings.recordingKeyPreset
        customRecordingKey = settings.customRecordingKey
        postTranscriptionAction = settings.postTranscriptionAction
        customPostTranscriptionKey = settings.customPostTranscriptionKey
    }

    func isDirty(comparedTo settings: AppSettings) -> Bool {
        speechEngine != settings.speechEngine ||
        whisperModelSize != settings.whisperModelSize ||
        useLLMProcessing != settings.useLLMProcessing ||
        textCleanupEngine != settings.textCleanupEngine ||
        liteLLMBaseURL != settings.liteLLMBaseURL ||
        liteLLMApiKey != settings.liteLLMApiKey ||
        llmModel != settings.llmModel ||
        writingStyle != settings.writingStyle ||
        formality != settings.formality ||
        removeFiller != settings.removeFiller ||
        autoFormat != settings.autoFormat ||
        recordingKeyPreset != settings.recordingKeyPreset ||
        customRecordingKey != settings.customRecordingKey ||
        postTranscriptionAction != settings.postTranscriptionAction ||
        customPostTranscriptionKey != settings.customPostTranscriptionKey
    }

    func apply(to settings: AppSettings) {
        settings.speechEngine = speechEngine
        settings.whisperModelSize = whisperModelSize
        settings.useLLMProcessing = useLLMProcessing
        settings.textCleanupEngine = textCleanupEngine
        settings.liteLLMBaseURL = liteLLMBaseURL
        settings.liteLLMApiKey = liteLLMApiKey
        settings.llmModel = llmModel
        settings.writingStyle = writingStyle
        settings.formality = formality
        settings.removeFiller = removeFiller
        settings.autoFormat = autoFormat
        settings.recordingKeyPreset = recordingKeyPreset
        settings.customRecordingKey = customRecordingKey
        settings.postTranscriptionAction = postTranscriptionAction
        settings.customPostTranscriptionKey = customPostTranscriptionKey
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController
    /// Synced up to MainView so nav-away can be intercepted.
    @Binding var isDirty: Bool

    @State private var draft: SettingsDraft
    @State private var isSaving = false

    private let brandColor = Color(red: 0.357, green: 0.310, blue: 0.914)

    init(settings: AppSettings, isDirty: Binding<Bool>) {
        self.settings = settings
        self._isDirty = isDirty
        self._draft = State(initialValue: SettingsDraft(from: settings))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        recordingHotkeySection
                        speechEngineSection
                        textCleanupSection
                        customDictionarySection
                        afterTranscriptionSection
                        PermissionsSection()
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }

                // Sticky save footer — always visible
                saveFooter
            }
            .background(Color.white)

            // Loading overlay — covers everything while saving
            if isSaving {
                savingOverlay
            }
        }
        .navigationTitle("")
        .onChange(of: draft.speechEngine)           { syncDirty() }
        .onChange(of: draft.whisperModelSize)       { syncDirty() }
        .onChange(of: draft.useLLMProcessing)       { syncDirty() }
        .onChange(of: draft.textCleanupEngine)      { syncDirty() }
        .onChange(of: draft.liteLLMBaseURL)         { syncDirty() }
        .onChange(of: draft.liteLLMApiKey)          { syncDirty() }
        .onChange(of: draft.llmModel)               { syncDirty() }
        .onChange(of: draft.writingStyle)           { syncDirty() }
        .onChange(of: draft.formality)              { syncDirty() }
        .onChange(of: draft.removeFiller)           { syncDirty() }
        .onChange(of: draft.autoFormat)             { syncDirty() }
        .onChange(of: draft.recordingKeyPreset)     { syncDirty() }
        .onChange(of: draft.postTranscriptionAction){ syncDirty() }
    }

    // MARK: - Sections

    private var recordingHotkeySection: some View {
        SettingsSection(title: "Recording Hotkey") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(RecordingKeyPreset.allCases, id: \.self) { preset in
                    RadioRow(
                        title: preset.rawValue,
                        subtitle: preset.description,
                        isSelected: draft.recordingKeyPreset == preset
                    ) {
                        draft.recordingKeyPreset = preset
                    }
                }

                if draft.recordingKeyPreset == .custom {
                    KeyCaptureField(
                        label: "Press a key combination",
                        binding: draft.customRecordingKey
                    ) { newBinding in
                        draft.customRecordingKey = newBinding
                        syncDirty()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var speechEngineSection: some View {
        SettingsSection(title: "Speech Engine") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Speech Engine", selection: $draft.speechEngine) {
                    Text("Apple Speech").tag(AppSettings.SpeechEngine.apple)
                    Text("Whisper").tag(AppSettings.SpeechEngine.whisper)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if draft.speechEngine == .whisper {
                    Picker("Model Size", selection: $draft.whisperModelSize) {
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
    }

    private var textCleanupSection: some View {
        SettingsSection(title: "Text Cleanup") {
            VStack(alignment: .leading, spacing: 12) {
                ToggleRow(title: "Enable AI Text Enhancement", isOn: $draft.useLLMProcessing)

                if draft.useLLMProcessing {
                    Divider()

                    Picker("Cleanup Engine", selection: $draft.textCleanupEngine) {
                        Text("Local SLM").tag(AppSettings.TextCleanupEngine.localSLM)
                        Text("Remote LLM").tag(AppSettings.TextCleanupEngine.remoteLLM)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if draft.textCleanupEngine == .remoteLLM {
                        LabeledField(label: "Base URL", placeholder: "http://127.0.0.1:4000", text: $draft.liteLLMBaseURL)
                        LabeledField(label: "Model", placeholder: "gpt-4o-mini", text: $draft.llmModel)
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
                                isSelected: draft.writingStyle == style
                            ) {
                                draft.writingStyle = style
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Formality")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Picker("Formality", selection: $draft.formality) {
                            ForEach(AppSettings.Formality.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider()

                    ToggleRow(title: "Remove filler words", isOn: $draft.removeFiller)
                    ToggleRow(title: "Auto-format punctuation & capitalization", isOn: $draft.autoFormat)
                }
            }
        }
    }

    private var customDictionarySection: some View {
        SettingsSection(title: "Custom Dictionary") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add technical terms, names, and jargon to improve recognition accuracy.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("Manage your dictionary from the Dictionary tab in the sidebar.")
                    .font(.system(size: 12))
                    .foregroundColor(brandColor)
            }
        }
    }

    private var afterTranscriptionSection: some View {
        SettingsSection(title: "After Transcription") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PostTranscriptionAction.allCases, id: \.self) { action in
                    RadioRow(
                        title: action.rawValue,
                        subtitle: action.description,
                        isSelected: draft.postTranscriptionAction == action
                    ) {
                        draft.postTranscriptionAction = action
                    }
                }

                if draft.postTranscriptionAction == .customKeyCombo {
                    KeyCaptureField(
                        label: "Press a key combination",
                        binding: draft.customPostTranscriptionKey
                    ) { newBinding in
                        draft.customPostTranscriptionKey = newBinding
                        syncDirty()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Save Footer

    private var saveFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if isDirty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Unsaved changes")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                } else {
                    Text("All changes saved")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    Text("Save Settings")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isDirty ? brandColor : Color.secondary.opacity(0.4))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!isDirty)
                .animation(.easeInOut(duration: 0.15), value: isDirty)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Color.white)
        }
        .animation(.easeInOut(duration: 0.2), value: isDirty)
    }

    // MARK: - Loading Overlay

    private var savingOverlay: some View {
        ZStack {
            Color.white.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(.circular)
                    .tint(brandColor)

                Text("Applying settings…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text("Loading models into memory")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func syncDirty() {
        isDirty = draft.isDirty(comparedTo: settings)
    }

    private func save() async {
        withAnimation { isSaving = true }

        draft.apply(to: settings)
        await controller.rebuildAndPreload(from: settings)

        withAnimation {
            isSaving = false
            isDirty = false
        }
    }

    /// Called by MainView when user discards — resets draft back to committed settings.
    func discardChanges() {
        draft = SettingsDraft(from: settings)
        isDirty = false
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

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                let captured = KeyBinding(
                    keyCode: event.keyCode,
                    modifiers: event.modifierFlags.intersection([.command, .option, .control, .shift, .function]).rawValue,
                    isModifierOnly: false
                )
                onCapture(captured)
                stopCapturing()
                return nil
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
    SettingsView(settings: AppSettings(), isDirty: .constant(false))
        .environmentObject(ConversationController(
            speechEngine: AppleSpeechEngine(),
            textProcessor: nil,
            settings: AppSettings()
        ))
}
