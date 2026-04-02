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
import os
import MLX
import MLXLLM
import MLXLMCommon

// MARK: - LocalSLMProcessor

final class LocalSLMProcessor: TextProcessingService {

    private var modelContainer: ModelContainer?
    private let modelId = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
    private let maxOutputChars = 4096

    // MARK: - TextProcessingService

    func process(text: String, systemPrompt: String) async throws -> String {
        if modelContainer == nil {
            AppLogger.models.info("model_load phase=start model=slm variant=\(self.modelId)")
            let loadStart = Date()
            let config = ModelConfiguration(id: modelId)
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)
            let elapsed = Int(Date().timeIntervalSince(loadStart) * 1000)
            AppLogger.models.info("model_load phase=complete model=slm variant=\(self.modelId) duration_ms=\(elapsed)")
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
        outer: for await generation in stream {
            switch generation {
            case .chunk(let chunk):
                output += chunk
                if output.count >= maxOutputChars { break outer }
            case .info:
                break
            default:
                break
            }
        }

        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Free intermediate inference buffers (KV cache, activations) after each run.
        Memory.clearCache()
        return result
    }

    // MARK: - Memory Management

    func unload() {
        AppLogger.models.info("model_unload model=slm variant=\(self.modelId) action=releasing_container")
        modelContainer = nil
        // MLX's caching allocator retains Metal GPU buffers in a pool after inference.
        // clearCache() forces them back to the OS immediately instead of accumulating.
        Memory.clearCache()
        AppLogger.models.info("model_unload model=slm action=cache_cleared")
    }

    deinit {
        AppLogger.models.info("model_dealloc model=slm")
    }
}
