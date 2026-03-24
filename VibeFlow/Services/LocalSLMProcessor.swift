// LocalSLMProcessor.swift
// VibeFlow
//
// Local small language model processor using MLX for fully offline text processing.
//
// Required SPM dependency: mlx-swift-lm
//   Add via Xcode: File > Add Package Dependencies...
//   URL: https://github.com/ml-explore/mlx-swift-lm
//   Products: MLXLLM, MLXLMCommon

import Foundation
import MLXLLM
import MLXLMCommon

// MARK: - LocalSLMProcessor

final class LocalSLMProcessor: TextProcessingService {

    private var modelContainer: ModelContainer?
    private let modelId = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
    private let maxTokens = 512

    // MARK: - TextProcessingService

    func process(text: String, systemPrompt: String) async throws -> String {
        if modelContainer == nil {
            print("🧠 Loading SLM model: \(modelId)...")
            let config = ModelConfiguration(id: modelId)
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
            print("🧠 Model loaded")
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalSLMProcessor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load model container"]
            )
        }

        let userInput = UserInput(
            chat: [
                .system(systemPrompt),
                .user(text)
            ]
        )

        let input = try await container.prepare(input: userInput)
        let stream = try await container.generate(
            input: input,
            parameters: GenerateParameters(temperature: 0.1)
        )

        var output = ""
        for await generation in stream {
            switch generation {
            case .chunk(let chunk):
                output += chunk
                if output.count >= maxTokens { break }
            case .info:
                break
            default:
                break
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Memory Management

    func unload() {
        modelContainer = nil
    }
}
