import Foundation

protocol TextProcessingService {
    func process(text: String, systemPrompt: String) async throws -> String
}
