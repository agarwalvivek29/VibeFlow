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
import os
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
    private var engineConfiguredForDevice: AudioDeviceID = 0

    // MARK: Whisper

    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif
    private var contextualTerms: [String] = []
    private let modelVariant: String

    /// Current load state — read by ConversationController after loadModel() completes.
    private(set) var loadState: ModelLoadState = .idle

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
        loadState = .loading
        let loadStart = Date()
        AppLogger.models.info("model_load phase=start model=whisper variant=\(self.modelVariant)")
        do {
            whisperKit = try await WhisperKit(model: "openai_whisper-\(modelVariant)")
            loadState = .loaded
            let elapsed = Int(Date().timeIntervalSince(loadStart) * 1000)
            AppLogger.models.info("model_load outcome=success model=whisper variant=\(self.modelVariant) duration_ms=\(elapsed)")
        } catch {
            loadState = .failed(error.localizedDescription)
            let elapsed = Int(Date().timeIntervalSince(loadStart) * 1000)
            AppLogger.models.error("model_load outcome=error model=whisper variant=\(self.modelVariant) error=\(error.localizedDescription) duration_ms=\(elapsed)")
        }
        #else
        loadState = .failed("WhisperKit dependency not installed")
        AppLogger.models.error("model_load outcome=error model=whisper reason=spm_dependency_missing")
        #endif
    }

    // MARK: - SpeechRecognitionService

    func startRecording(contextualTerms: [String], preferredDeviceUID: String? = nil) throws {
        self.contextualTerms = contextualTerms

        // Remove old tap — but do NOT stop the engine if it's already configured for the right device
        audioEngine.inputNode.removeTap(onBus: 0)
        stopLevelTimer()

        audioBuffer = []
        transcript = ""

        #if os(macOS)
        // Log available input devices
        let allDevices = AudioDeviceManager.listInputDevices()
        let deviceList = allDevices.map { "\($0.name) (uid=\($0.uid), rate=\(Int($0.sampleRate)))" }.joined(separator: ", ")
        AppLogger.audio.info("audio_devices engine=whisper count=\(allDevices.count) devices=[\(deviceList)]")

        // Resolve the target device
        let targetDevice: AudioInputDevice?
        if let uid = preferredDeviceUID, let device = allDevices.first(where: { $0.uid == uid }) {
            targetDevice = device
        } else {
            targetDevice = AudioDeviceManager.getDefaultInputDevice()
        }

        guard let device = targetDevice else {
            AppLogger.audio.error("recording outcome=error engine=whisper reason=no_input_device")
            throw NSError(domain: "WhisperEngine", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No input device available"])
        }

        deviceSampleRate = device.sampleRate
        AppLogger.audio.info("audio_device_resolution engine=whisper device=\(device.name) device_id=\(device.id) rate=\(Int(device.sampleRate))")

        // Only reconfigure the engine if the device changed or engine isn't running.
        // Keeping the engine alive between recordings avoids the CoreAudio I/O thread
        // restart issue (HALB_IOThread: there already is a thread).
        let needsEngineRestart = !audioEngine.isRunning || device.id != engineConfiguredForDevice
        if needsEngineRestart {
            if audioEngine.isRunning { audioEngine.stop() }
            audioEngine.reset()

            // Point the engine at the REAL device, bypassing the CADefaultDeviceAggregate.
            // Without this, AVAudioEngine connects to the aggregate device which reports
            // a wrong sample rate (e.g. 44100) while the actual BT hardware is 16000.
            let inputNode = audioEngine.inputNode
            if let audioUnit = inputNode.audioUnit {
                var deviceIDToSet = device.id
                let setStatus = AudioUnitSetProperty(
                    audioUnit, kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global, 0,
                    &deviceIDToSet, UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                AppLogger.audio.info("audio_unit_set_device engine=whisper status=\(setStatus) device_id=\(device.id) device=\(device.name)")
            }
            engineConfiguredForDevice = device.id
        } else {
            AppLogger.audio.info("audio_engine engine=whisper reusing_running device=\(device.name)")
        }

        // Use the real device's format for the tap
        let tapFormat = AVAudioFormat(standardFormatWithSampleRate: device.sampleRate, channels: 1)
        #else
        let tapFormat: AVAudioFormat? = nil
        let needsEngineRestart = !audioEngine.isRunning
        #endif

        let inputNode = audioEngine.inputNode

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frames))
            self.audioBuffer.append(contentsOf: samples)
            if self.audioBuffer.count > self.maxBufferSize {
                self.audioBuffer = Array(self.audioBuffer.suffix(self.maxBufferSize))
            }
            self.updateLevel(from: buffer)
        }

        if needsEngineRestart {
            audioEngine.prepare()
            try audioEngine.start()
        }
        AppLogger.audio.info("recording phase=active engine=whisper sample_rate=\(Int(self.deviceSampleRate)) engine_restarted=\(needsEngineRestart)")
        startLevelTimer()
    }

    func stopAndWaitForFinal() async -> String {
        // Remove tap but keep engine running — avoids I/O thread restart on next recording
        audioEngine.inputNode.removeTap(onBus: 0)
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
            AppLogger.audio.error("recording outcome=error engine=whisper reason=model_not_loaded")
            return ""
        }

        let transcribeStart = Date()
        do {
            let options = DecodingOptions(
                language: "en"
            )
            let results: [TranscriptionResult] = try await kit.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let elapsed = Int(Date().timeIntervalSince(transcribeStart) * 1000)
            AppLogger.audio.info("transcription outcome=success engine=whisper chars=\(text.count) duration_ms=\(elapsed)")
            transcript = text
            return text
        } catch {
            let elapsed = Int(Date().timeIntervalSince(transcribeStart) * 1000)
            AppLogger.audio.error("transcription outcome=error engine=whisper error=\(error.localizedDescription) duration_ms=\(elapsed)")
            return ""
        }
        #else
        AppLogger.audio.error("transcription outcome=error engine=whisper reason=spm_dependency_missing")
        return ""
        #endif
    }

    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        engineConfiguredForDevice = 0
        stopLevelTimer()
        audioBuffer = []
    }

    deinit {
        AppLogger.models.info("model_dealloc model=whisper variant=\(self.modelVariant)")
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
