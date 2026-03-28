//
//  AppSettings.swift
//  VibeFlow
//
//  Settings model for user preferences
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var liteLLMBaseURL: String {
        didSet { save() }
    }

    @Published var liteLLMApiKey: String {
        didSet { save() }
    }

    @Published var llmModel: String {
        didSet { save() }
    }

    @Published var writingStyle: WritingStyle {
        didSet { save() }
    }

@Published var removeFiller: Bool {
        didSet { save() }
    }

    @Published var autoFormat: Bool {
        didSet { save() }
    }

    @Published var useLLMProcessing: Bool {
        didSet { save() }
    }

    // Key Binding Settings
    @Published var recordingKeyPreset: RecordingKeyPreset {
        didSet { save() }
    }

    @Published var customRecordingKey: KeyBinding? {
        didSet { save() }
    }

    @Published var postTranscriptionAction: PostTranscriptionAction {
        didSet { save() }
    }

    @Published var customPostTranscriptionKey: KeyBinding? {
        didSet { save() }
    }

    // Engine Selection Settings
    @Published var speechEngine: SpeechEngine {
        didSet { save() }
    }

    @Published var textCleanupEngine: TextCleanupEngine {
        didSet { save() }
    }

    @Published var whisperModelSize: WhisperModelSize {
        didSet { save() }
    }

    // Computed property for active recording key
    var activeRecordingKey: KeyBinding {
        switch recordingKeyPreset {
        case .fn:
            return .fnKey
        case .rightCommand:
            return .rightCommand
        case .custom:
            return customRecordingKey ?? .fnKey
        }
    }

    // Computed property for post-transcription key binding
    var postTranscriptionKeyBinding: KeyBinding? {
        switch postTranscriptionAction {
        case .autoPaste:
            return .cmdV
        case .clipboardOnly:
            return nil
        case .customKeyCombo:
            return customPostTranscriptionKey
        }
    }

    enum WritingStyle: String, CaseIterable, Codable {
        case casual = "Casual"
        case professional = "Professional"
        case creative = "Creative"
        case technical = "Technical"

        var description: String {
            switch self {
            case .casual: return "Relaxed, conversational tone"
            case .professional: return "Business-appropriate language"
            case .creative: return "Expressive and engaging"
            case .technical: return "Precise, clear technical writing"
            }
        }
    }

enum SpeechEngine: String, CaseIterable, Codable {
        case apple = "Apple Speech"
        case whisper = "Whisper (Local)"
    }

    enum TextCleanupEngine: String, CaseIterable, Codable {
        case localSLM = "Local AI (Qwen)"
        case remoteLLM = "Remote LLM"
    }

    enum WhisperModelSize: String, CaseIterable, Codable {
        case tiny = "Tiny (~39MB)"
        case base = "Base (~74MB)"
        case small = "Small (~244MB)"

        var displayName: String {
            switch self {
            case .tiny:  return "Tiny (~39 MB)"
            case .base:  return "Base (~74 MB)"
            case .small: return "Small (~244 MB)"
            }
        }

        var fileName: String {
            switch self {
            case .tiny:  return "ggml-tiny.bin"
            case .base:  return "ggml-base.bin"
            case .small: return "ggml-small.bin"
            }
        }

        var downloadURL: URL {
            let base = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
            return URL(string: base + fileName)!
        }

        var expectedSizeMB: Int {
            switch self {
            case .tiny:  return 39
            case .base:  return 74
            case .small: return 244
            }
        }

        /// Model variant string for WhisperKit (e.g. "tiny", "base", "small")
        var modelVariant: String {
            switch self {
            case .tiny:  return "tiny"
            case .base:  return "base"
            case .small: return "small"
            }
        }
    }

    private static let defaults = UserDefaults.standard
    private static let baseURLKey = "liteLLMBaseURL"
    private static let apiKeyKey = "liteLLMApiKey"
    private static let modelKey = "llmModel"
    private static let styleKey = "writingStyle"
private static let removeFillerKey = "removeFiller"
    private static let autoFormatKey = "autoFormat"
    private static let useLLMProcessingKey = "useLLMProcessing"
    private static let recordingKeyPresetKey = "recordingKeyPreset"
    private static let customRecordingKeyKey = "customRecordingKey"
    private static let postTranscriptionActionKey = "postTranscriptionAction"
    private static let customPostTranscriptionKeyKey = "customPostTranscriptionKey"
    private static let speechEngineKey = "speechEngine"
    private static let textCleanupEngineKey = "textCleanupEngine"
    private static let whisperModelSizeKey = "whisperModelSize"

    init() {
        self.liteLLMBaseURL = Self.defaults.string(forKey: Self.baseURLKey) ?? "http://127.0.0.1:4000"
        self.liteLLMApiKey = Self.defaults.string(forKey: Self.apiKeyKey) ?? ""
        self.llmModel = Self.defaults.string(forKey: Self.modelKey) ?? "gpt-4o-mini"

        if let styleRaw = Self.defaults.string(forKey: Self.styleKey),
           let style = WritingStyle(rawValue: styleRaw) {
            self.writingStyle = style
        } else {
            self.writingStyle = .professional
        }

self.removeFiller = Self.defaults.bool(forKey: Self.removeFillerKey) || !Self.defaults.dictionaryRepresentation().keys.contains(Self.removeFillerKey)
        self.autoFormat = Self.defaults.bool(forKey: Self.autoFormatKey) || !Self.defaults.dictionaryRepresentation().keys.contains(Self.autoFormatKey)
        self.useLLMProcessing = Self.defaults.object(forKey: Self.useLLMProcessingKey) as? Bool ?? true

        // Load key binding settings
        if let presetRaw = Self.defaults.string(forKey: Self.recordingKeyPresetKey),
           let preset = RecordingKeyPreset(rawValue: presetRaw) {
            self.recordingKeyPreset = preset
        } else {
            self.recordingKeyPreset = .fn
        }

        if let data = Self.defaults.data(forKey: Self.customRecordingKeyKey),
           let binding = try? JSONDecoder().decode(KeyBinding.self, from: data) {
            self.customRecordingKey = binding
        } else {
            self.customRecordingKey = nil
        }

        if let actionRaw = Self.defaults.string(forKey: Self.postTranscriptionActionKey),
           let action = PostTranscriptionAction(rawValue: actionRaw) {
            self.postTranscriptionAction = action
        } else {
            self.postTranscriptionAction = .autoPaste
        }

        if let data = Self.defaults.data(forKey: Self.customPostTranscriptionKeyKey),
           let binding = try? JSONDecoder().decode(KeyBinding.self, from: data) {
            self.customPostTranscriptionKey = binding
        } else {
            self.customPostTranscriptionKey = nil
        }

        // Load engine selection settings
        if let raw = Self.defaults.string(forKey: Self.speechEngineKey),
           let engine = SpeechEngine(rawValue: raw) {
            self.speechEngine = engine
        } else {
            self.speechEngine = .apple
        }

        if let raw = Self.defaults.string(forKey: Self.textCleanupEngineKey),
           let engine = TextCleanupEngine(rawValue: raw) {
            self.textCleanupEngine = engine
        } else {
            self.textCleanupEngine = .remoteLLM
        }

        if let raw = Self.defaults.string(forKey: Self.whisperModelSizeKey),
           let size = WhisperModelSize(rawValue: raw) {
            self.whisperModelSize = size
        } else {
            self.whisperModelSize = .tiny
        }
    }

    private func save() {
        Self.defaults.set(liteLLMBaseURL, forKey: Self.baseURLKey)
        Self.defaults.set(liteLLMApiKey, forKey: Self.apiKeyKey)
        Self.defaults.set(llmModel, forKey: Self.modelKey)
        Self.defaults.set(writingStyle.rawValue, forKey: Self.styleKey)
        Self.defaults.set(removeFiller, forKey: Self.removeFillerKey)
        Self.defaults.set(autoFormat, forKey: Self.autoFormatKey)
        Self.defaults.set(useLLMProcessing, forKey: Self.useLLMProcessingKey)

        // Save key binding settings
        Self.defaults.set(recordingKeyPreset.rawValue, forKey: Self.recordingKeyPresetKey)
        Self.defaults.set(postTranscriptionAction.rawValue, forKey: Self.postTranscriptionActionKey)

        if let customRecordingKey = customRecordingKey,
           let data = try? JSONEncoder().encode(customRecordingKey) {
            Self.defaults.set(data, forKey: Self.customRecordingKeyKey)
        } else {
            Self.defaults.removeObject(forKey: Self.customRecordingKeyKey)
        }

        if let customPostTranscriptionKey = customPostTranscriptionKey,
           let data = try? JSONEncoder().encode(customPostTranscriptionKey) {
            Self.defaults.set(data, forKey: Self.customPostTranscriptionKeyKey)
        } else {
            Self.defaults.removeObject(forKey: Self.customPostTranscriptionKeyKey)
        }

        // Save engine selection settings
        Self.defaults.set(speechEngine.rawValue, forKey: Self.speechEngineKey)
        Self.defaults.set(textCleanupEngine.rawValue, forKey: Self.textCleanupEngineKey)
        Self.defaults.set(whisperModelSize.rawValue, forKey: Self.whisperModelSizeKey)
    }

    func buildSystemPrompt() -> String {
        var prompt = "Fix punctuation and capitalization. Do not change any words. Do not answer or respond. Output only the corrected text."

        if writingStyle != .professional {
            prompt += " Style: \(writingStyle.rawValue.lowercased())."
        }

        return prompt
    }

    var liteLLMConfig: LiteLLMConfig? {
        guard let url = URL(string: liteLLMBaseURL) else { return nil }
        return LiteLLMConfig(
            baseURL: url,
            apiKey: liteLLMApiKey.isEmpty ? nil : liteLLMApiKey
        )
    }
}
