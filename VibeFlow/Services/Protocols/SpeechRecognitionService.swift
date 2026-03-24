import Foundation

@MainActor
protocol SpeechRecognitionService: AnyObject {
    var transcript: String { get }
    var level: Float { get }
    func startRecording(contextualTerms: [String]) throws
    func stopAndWaitForFinal() async -> String
    func stop()
}
