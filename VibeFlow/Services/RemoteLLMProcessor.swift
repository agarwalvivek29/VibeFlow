import Foundation

final class RemoteLLMProcessor: TextProcessingService {
    private let client: LiteLLMClient
    private let model: String

    init(client: LiteLLMClient, model: String) {
        self.client = client
        self.model = model
    }

    func process(text: String, systemPrompt: String) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        let stream = try await client.streamChatCompletion(model: model, messages: messages)
        var result = ""
        for try await token in stream {
            result.append(token)
        }
        return result
    }
}
