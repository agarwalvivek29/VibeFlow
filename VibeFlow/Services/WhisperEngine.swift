// WhisperEngine.swift
// VibeFlow
//
// WhisperKit-based speech recognition engine for fully offline transcription.
//
// Required SPM dependency: WhisperKit
//   Add via Xcode: File > Add Package Dependencies...
//   URL: https://github.com/argmaxinc/WhisperKit.git
//   Then select the "WhisperKit" product.

import Foundation
import AVFoundation
import Accelerate
import Combine
#if os(macOS)
import CoreAudio
#endif

#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - WhisperEngine

@MainActor
final class WhisperEngine: NSObject, ObservableObject, SpeechRecognitionService {

    // MARK: Published

    @Published var transcript: String = ""
    @Published var level: Float = 0.0

    // MARK: Audio

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var deviceSampleRate: Double = 16000
    private let maxBufferSize = 14_400_000 // 5 minutes at 48 kHz

    // MARK: Whisper

    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif
    private var contextualTerms: [String] = []
    private let modelVariant: String

    // MARK: Level metering

    private var pendingLevel: Float = 0
    private var levelTimer: Timer?

    // MARK: - Init

    /// Initialize with a Whisper model variant name (e.g. "tiny", "base", "small").
    /// WhisperKit downloads and caches the model automatically on first use.
    init(modelVariant: String = "tiny") {
        self.modelVariant = modelVariant
        super.init()
    }

    /// Load the WhisperKit pipeline. Call this before first transcription.
    func loadModel() async {
        #if canImport(WhisperKit)
        do {
            whisperKit = try await WhisperKit(model: "openai_whisper-\(modelVariant)")
        } catch {
            print("Failed to load WhisperKit model '\(modelVariant)': \(error)")
        }
        #else
        print("WhisperKit SPM dependency not installed — WhisperEngine unavailable")
        #endif
    }

    // MARK: - SpeechRecognitionService

    func startRecording(contextualTerms: [String]) throws {
        self.contextualTerms = contextualTerms

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        stopLevelTimer()

        Thread.sleep(forTimeInterval: 0.05)

        audioBuffer = []
        transcript = ""

        #if os(macOS)
        var defaultDeviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &propertySize, &defaultDeviceID
        )

        guard status == noErr, defaultDeviceID != 0 else {
            throw NSError(domain: "WhisperEngine", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No input device available"])
        }

        var sampleRate: Float64 = 0
        var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let sampleRateStatus = AudioObjectGetPropertyData(
            defaultDeviceID, &sampleRateAddress, 0, nil, &sampleRateSize, &sampleRate
        )

        if sampleRateStatus == noErr, sampleRate > 0 {
            deviceSampleRate = sampleRate
        } else {
            deviceSampleRate = 48000
        }

        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        if let audioUnit = inputNode.audioUnit {
            var deviceIDToSet = defaultDeviceID
            AudioUnitSetProperty(
                audioUnit, kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global, 0,
                &deviceIDToSet, UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        let tapFormat: AVAudioFormat?
        if hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 {
            tapFormat = hardwareFormat
            deviceSampleRate = hardwareFormat.sampleRate
        } else {
            tapFormat = nil
        }
        #else
        let inputNode = audioEngine.inputNode
        let tapFormat = inputNode.outputFormat(forBus: 0)
        deviceSampleRate = tapFormat.sampleRate
        #endif

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frames))
            self.audioBuffer.append(contentsOf: samples)
            if self.audioBuffer.count > self.maxBufferSize {
                self.audioBuffer.removeFirst(self.audioBuffer.count - self.maxBufferSize)
            }
            self.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        startLevelTimer()
    }

    func stopAndWaitForFinal() async -> String {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        stopLevelTimer()

        let samples = resampleTo16kHz(audioBuffer, from: deviceSampleRate)
        audioBuffer.removeAll(keepingCapacity: false)

        guard !samples.isEmpty else { return "" }

        #if canImport(WhisperKit)
        // Lazy-load model if needed
        if whisperKit == nil {
            await loadModel()
        }

        guard let kit = whisperKit else {
            print("WhisperKit not loaded — cannot transcribe")
            return ""
        }

        do {
            let options = DecodingOptions(
                language: "en"
            )
            let results: [TranscriptionResult] = try await kit.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            transcript = text
            return text
        } catch {
            print("WhisperKit transcription failed: \(error)")
            return ""
        }
        #else
        print("WhisperKit SPM dependency not installed — transcription unavailable")
        return ""
        #endif
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        stopLevelTimer()
        audioBuffer = []
    }

    // MARK: - Resampling

    private func resampleTo16kHz(_ input: [Float], from sourceSampleRate: Double) -> [Float] {
        let targetRate: Double = 16000
        guard sourceSampleRate != targetRate, !input.isEmpty else { return input }

        let ratio = targetRate / sourceSampleRate
        let outputLength = Int(Double(input.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)
        var control = (0..<outputLength).map { Float(Double($0) / ratio) }
        vDSP_vlint(input, &control, 1, &output, 1, vDSP_Length(outputLength), vDSP_Length(input.count))
        return output
    }

    // MARK: - Level Metering

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.sampleLevel()
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        var mean: Float = 0
        vDSP_meamgv(ch[0], 1, &mean, vDSP_Length(frames))
        pendingLevel = min(max(sqrtf(mean) * 10, 0), 1)
    }

    private func sampleLevel() {
        let smoothed = (level * 0.8) + (pendingLevel * 0.2)
        if abs(smoothed - level) > 0.001 { level = smoothed }
    }
}
