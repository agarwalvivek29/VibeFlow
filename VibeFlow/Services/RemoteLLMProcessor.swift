import Foundation

final class RemoteLLMProcessor: TextProcessingService {
    private let client: LiteLLMClient
    private let model: String

    init(client: LiteLLMClient, model: String) {
        self.client = client
        self.model = model
    }

    func process(text: String, systemPrompt: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "RemoteLLMProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty text input"])
        }

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
            throw NSError(domain: "RemoteLLMProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM returned empty result"])
        }

        return result
    }
}
