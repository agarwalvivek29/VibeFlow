import Foundation

struct LiteLLMConfig {
    var baseURL: URL
    var apiKey: String?
}

final class LiteLLMClient {
    let config: LiteLLMConfig
    init(config: LiteLLMConfig) { self.config = config }

    // Transcribe audio already converted to text (we use SFSpeechRecognizer for now).
    // This is kept for future server-side STT if desired.
    func transcribe(data: Data, model: String) async throws -> String {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("/v1/audio/transcriptions"))
        req.httpMethod = "POST"
        if let key = config.apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        // Implement multipart form if needed. Placeholder:
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        let (d, _) = try await URLSession.shared.data(for: req)
        // Expecting { "text": "..." }
        let obj = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        return obj?["text"] as? String ?? ""
    }

    func streamChatCompletion(model: String, messages: [[String: String]]) async throws -> AsyncThrowingStream<String, Error> {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("/v1/chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = config.apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        var iterator = bytes.lines.makeAsyncIterator()
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    while let line = try await iterator.next() {
                        // Handle SSE lines like: data: {"choices":[{"delta":{"content":"..."}}]}
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let d = payload.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                           let choices = obj["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let token = delta["content"] as? String {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
