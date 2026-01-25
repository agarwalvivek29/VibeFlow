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

    @Published var formality: Formality {
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

    enum Formality: String, CaseIterable, Codable {
        case informal = "Informal"
        case neutral = "Neutral"
        case formal = "Formal"
    }

    private static let defaults = UserDefaults.standard
    private static let baseURLKey = "liteLLMBaseURL"
    private static let apiKeyKey = "liteLLMApiKey"
    private static let modelKey = "llmModel"
    private static let styleKey = "writingStyle"
    private static let formalityKey = "formality"
    private static let removeFillerKey = "removeFiller"
    private static let autoFormatKey = "autoFormat"
    private static let useLLMProcessingKey = "useLLMProcessing"

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

        if let formalityRaw = Self.defaults.string(forKey: Self.formalityKey),
           let formality = Formality(rawValue: formalityRaw) {
            self.formality = formality
        } else {
            self.formality = .neutral
        }

        self.removeFiller = Self.defaults.bool(forKey: Self.removeFillerKey) || !Self.defaults.dictionaryRepresentation().keys.contains(Self.removeFillerKey)
        self.autoFormat = Self.defaults.bool(forKey: Self.autoFormatKey) || !Self.defaults.dictionaryRepresentation().keys.contains(Self.autoFormatKey)
        self.useLLMProcessing = Self.defaults.object(forKey: Self.useLLMProcessingKey) as? Bool ?? true
    }

    private func save() {
        Self.defaults.set(liteLLMBaseURL, forKey: Self.baseURLKey)
        Self.defaults.set(liteLLMApiKey, forKey: Self.apiKeyKey)
        Self.defaults.set(llmModel, forKey: Self.modelKey)
        Self.defaults.set(writingStyle.rawValue, forKey: Self.styleKey)
        Self.defaults.set(formality.rawValue, forKey: Self.formalityKey)
        Self.defaults.set(removeFiller, forKey: Self.removeFillerKey)
        Self.defaults.set(autoFormat, forKey: Self.autoFormatKey)
        Self.defaults.set(useLLMProcessing, forKey: Self.useLLMProcessingKey)
    }

    func buildSystemPrompt() -> String {
        var prompt = "You are a dictation assistant. Your job is to take spoken transcriptions and convert them into polished, well-formatted text."

        if removeFiller {
            prompt += " Remove filler words like 'um', 'uh', 'like', 'you know', etc."
        }

        if autoFormat {
            prompt += " Add proper punctuation, capitalization, and paragraph breaks."
        }

        prompt += " Use a \(writingStyle.rawValue.lowercased()) writing style."

        switch formality {
        case .informal:
            prompt += " Keep the tone informal and friendly."
        case .neutral:
            prompt += " Use a neutral, balanced tone."
        case .formal:
            prompt += " Use formal, polished language."
        }

        prompt += " Do NOT add extra content - only clean up what was spoken. Return ONLY the cleaned text, no explanations or meta-commentary."

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
