// LocalSLMProcessor.swift
// VibeFlow
//
// Local small language model processor using MLX for fully offline text processing.
//
// Required SPM dependencies: mlx-swift-examples
//   Add via Xcode: File > Add Package Dependencies...
//   URL: https://github.com/ml-explore/mlx-swift-examples
//   Then add the "LLM" library product to your target.

import Foundation
import LLM
import MLX
import MLXRandom
import MLXLMCommon

// MARK: - Protocol

protocol TextProcessingService {
    func process(text: String, systemPrompt: String) async throws -> String
}

// MARK: - LocalSLMProcessor

final class LocalSLMProcessor: TextProcessingService {

    private var modelContainer: ModelContainer?
    private let modelId = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
    private let maxTokens = 512

    // MARK: - TextProcessingService

    func process(text: String, systemPrompt: String) async throws -> String {
        if modelContainer == nil {
            let config = ModelConfiguration(id: modelId)
            modelContainer = try await LLM.ModelFactory.shared.loadContainer(configuration: config)
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalSLMProcessor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load model container"]
            )
        }

        let prompt = """
        <|im_start|>system
        \(systemPrompt)<|im_end|>
        <|im_start|>user
        \(text)<|im_end|>
        <|im_start|>assistant
        """

        let maxTok = maxTokens
        let result = try await container.perform { context in
            let input = try await context.tokenize(prompt)
            var output = ""
            _ = try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: 0.1),
                context: context
            ) { tokens in
                let decoded = context.tokenizer.decode(tokens: tokens)
                output = decoded
                return output.count < maxTok ? .more : .stop
            }
            return output
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Memory Management

    /// Unload the model from memory when not needed.
    func unload() {
        modelContainer = nil
    }
}
