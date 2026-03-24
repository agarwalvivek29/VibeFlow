// WhisperEngine.swift
// VibeFlow
//
// Whisper.cpp-based speech recognition engine for fully offline transcription.
//
// Required SPM dependency: whisper.cpp
//   Add via Xcode: File > Add Package Dependencies...
//   URL: https://github.com/ggerganov/whisper.cpp
//   Then import the "whisper" library product.

import Foundation
import AVFoundation
import Accelerate
import Combine
#if os(macOS)
import CoreAudio
#endif

#if canImport(whisper)
import whisper
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
    /// Max buffer size: 5 minutes at 48 kHz
    private let maxBufferSize = 14_400_000

    // MARK: Whisper

    private let modelPath: URL
    private var whisperContext: OpaquePointer?
    private var contextualTerms: [String] = []

    // MARK: Level metering

    private var pendingLevel: Float = 0
    private var levelTimer: Timer?

    // MARK: - Init

    init(modelPath: URL) {
        self.modelPath = modelPath
        super.init()
        #if canImport(whisper)
        whisperContext = whisper_init_from_file(modelPath.path)
        if whisperContext == nil {
            print("Failed to load Whisper model at \(modelPath.path)")
        }
        #else
        print("whisper.cpp SPM dependency not installed — WhisperEngine unavailable")
        #endif
    }

    deinit {
        #if canImport(whisper)
        if let ctx = whisperContext {
            whisper_free(ctx)
        }
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
        // Get the system default input device
        var defaultDeviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )

        guard status == noErr, defaultDeviceID != 0 else {
            throw NSError(
                domain: "WhisperEngine",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No input device available"]
            )
        }

        // Get the device's native sample rate
        var sampleRate: Float64 = 0
        var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let sampleRateStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &sampleRateAddress,
            0,
            nil,
            &sampleRateSize,
            &sampleRate
        )

        if sampleRateStatus == noErr, sampleRate > 0 {
            deviceSampleRate = sampleRate
        } else {
            deviceSampleRate = 48000
        }

        // Stop and reset audio engine to ensure clean state
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()

        // Set the input device on the audio unit
        let inputNode = audioEngine.inputNode
        if let audioUnit = inputNode.audioUnit {
            var deviceIDToSet = defaultDeviceID
            let setStatus = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceIDToSet,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if setStatus != noErr {
                print("Failed to set audio input device (status: \(setStatus))")
            }
        }

        // Get the format after setting the device
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
            // Prevent unbounded memory growth — drop oldest samples
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

        guard let ctx = whisperContext else {
            return ""
        }

        let samples = resampleTo16kHz(audioBuffer, from: deviceSampleRate)
        audioBuffer.removeAll(keepingCapacity: false)

        #if canImport(whisper)
        let terms = contextualTerms
        let result: String = await Task.detached { [samples] in
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_progress = false
            params.print_timestamps = false

            let langPtr = strdup("en")
            params.language = UnsafePointer(langPtr)

            let promptText = terms.joined(separator: ", ")
            let promptPtr = strdup(promptText)
            params.initial_prompt = UnsafePointer(promptPtr)

            let sampleCount = Int32(samples.count)
            let status = samples.withUnsafeBufferPointer { bufferPtr in
                whisper_full(ctx, params, bufferPtr.baseAddress, sampleCount)
            }

            free(langPtr)
            free(promptPtr)

            guard status == 0 else { return "" }

            let segmentCount = whisper_full_n_segments(ctx)
            var fullText = ""
            for i in 0..<segmentCount {
                if let cStr = whisper_full_get_segment_text(ctx, i) {
                    fullText += String(cString: cStr)
                }
            }
            return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
        #else
        let result = ""
        print("whisper.cpp SPM dependency not installed — transcription unavailable")
        #endif

        transcript = result
        return result
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        stopLevelTimer()
        audioBuffer = []
    }

    // MARK: - Resampling

    /// Resample audio from the device sample rate to 16 kHz for Whisper.
    private func resampleTo16kHz(_ input: [Float], from sourceSampleRate: Double) -> [Float] {
        let targetRate: Double = 16000
        guard sourceSampleRate != targetRate, !input.isEmpty else {
            return input
        }

        let ratio = targetRate / sourceSampleRate
        let outputLength = Int(Double(input.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)

        // Use vDSP linear interpolation for resampling
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
        let rms = sqrtf(mean)
        let normalized = min(max(rms * 10, 0), 1)
        pendingLevel = normalized
    }

    private func sampleLevel() {
        let smoothed = (level * 0.8) + (pendingLevel * 0.2)
        if abs(smoothed - level) > 0.001 {
            level = smoothed
        }
    }
}
