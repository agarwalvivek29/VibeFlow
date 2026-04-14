import Foundation
import os

final class RemoteLLMProcessor: TextProcessingService {
    private let client: LiteLLMClient
    private let model: String

    init(client: LiteLLMClient, model: String) {
        self.client = client
        self.model = model
    }

    func process(text: String, systemPrompt: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLogger.pipeline.error("remote_llm outcome=error model=\(self.model) reason=empty_input")
            throw NSError(domain: "RemoteLLMProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty text input"])
        }

        let inputLen = text.count
        AppLogger.pipeline.info("remote_llm phase=start model=\(self.model) input_chars=\(inputLen)")
        let start = Date()

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        let stream = try await client.streamChatCompletion(model: model, messages: messages)
        var result = ""
        for try await token in stream {
            result.append(token)
        }

        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            AppLogger.pipeline.error("remote_llm outcome=error model=\(self.model) reason=empty_response duration_ms=\(elapsed)")
            throw NSError(domain: "RemoteLLMProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM returned empty result"])
        }

        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        AppLogger.pipeline.info("remote_llm outcome=success model=\(self.model) input_chars=\(inputLen) output_chars=\(result.count) duration_ms=\(elapsed)")
        return result
    }
}
