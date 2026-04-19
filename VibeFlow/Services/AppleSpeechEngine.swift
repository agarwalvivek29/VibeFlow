import Foundation
import os
import AVFoundation
import Speech
import Combine
import Accelerate
#if os(macOS)
import CoreAudio
#endif

final class AppleSpeechEngine: NSObject, ObservableObject, SpeechRecognitionService {
    @Published var transcript: String = ""
    @Published var level: Float = 0.0 // 0...1 for waveform UI

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    private var levelTimer: Timer?

    // Continuation for async stop - waits for isFinal
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var isWaitingForFinal = false
    private var hasResumedContinuation = false

    func requestPermissions() async throws {
        // Permissions are now handled by PermissionsHelper
        // This method is kept for compatibility
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
        #endif
        // No-op on macOS
    }

    func startRecording(contextualTerms: [String] = [], preferredDeviceUID: String? = nil) throws {
        AppLogger.audio.info("recording phase=start engine=apple")

        // Clean stop — remove tap, stop engine, reset
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine.reset()
        stopLevelTimer()

        transcript = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            AppLogger.audio.error("recording outcome=error engine=apple reason=recognizer_unavailable")
            throw NSError(domain: "AppleSpeechEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        #if os(macOS)
        // Log available input devices for diagnostics
        let allDevices = AudioDeviceManager.listInputDevices()
        let deviceList = allDevices.map { "\($0.name) (uid=\($0.uid), rate=\(Int($0.sampleRate)))" }.joined(separator: ", ")
        AppLogger.audio.info("audio_devices engine=apple count=\(allDevices.count) devices=[\(deviceList)]")

        if let defaultDevice = AudioDeviceManager.getDefaultInputDevice() {
            AppLogger.audio.info("audio_device_resolution engine=apple using=system_default device=\(defaultDevice.name) device_id=\(defaultDevice.id) rate=\(Int(defaultDevice.sampleRate))")
        }
        #endif

        // Use nil format — let AVAudioEngine handle device selection and format conversion.
        let inputNode = audioEngine.inputNode

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualTerms
        self.recognitionRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        let hwFormat = inputNode.inputFormat(forBus: 0)
        AppLogger.audio.info("recording phase=active engine=apple sample_rate=\(Int(hwFormat.sampleRate)) hw_channels=\(hwFormat.channelCount) running=\(self.audioEngine.isRunning)")

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                }

                if result.isFinal {
                    if self.isWaitingForFinal, !self.hasResumedContinuation {
                        self.hasResumedContinuation = true
                        self.isWaitingForFinal = false
                        self.stopContinuation?.resume(returning: text)
                        self.stopContinuation = nil
                        self.cleanup()
                    }
                }
            }

            if let error = error {
                AppLogger.audio.error("recognition outcome=error engine=apple error=\(error.localizedDescription)")
                if self.isWaitingForFinal, !self.hasResumedContinuation {
                    self.hasResumedContinuation = true
                    self.isWaitingForFinal = false
                    self.stopContinuation?.resume(returning: self.transcript)
                    self.stopContinuation = nil
                    self.cleanup()
                }
            }
        }

        startLevelTimer()
    }

    /// Stops recording and waits for the final transcription result
    func stopAndWaitForFinal() async -> String {
        AppLogger.audio.info("recording phase=stop_and_wait engine=apple transcript_chars=\(self.transcript.count)")

        guard audioEngine.isRunning else {
            AppLogger.audio.info("recording phase=stop_and_wait engine=apple reason=engine_not_running")
            return transcript
        }

        return await withCheckedContinuation { continuation in
            self.hasResumedContinuation = false
            self.stopContinuation = continuation
            self.isWaitingForFinal = true

            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine.stop()
            self.stopLevelTimer()
            AppLogger.audio.info("recording phase=waiting_for_final engine=apple")

            self.recognitionRequest?.endAudio()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, self.isWaitingForFinal, !self.hasResumedContinuation else { return }
                AppLogger.audio.info("recording phase=timeout_fallback engine=apple transcript_chars=\(self.transcript.count)")
                self.hasResumedContinuation = true
                self.isWaitingForFinal = false
                self.stopContinuation?.resume(returning: self.transcript)
                self.stopContinuation = nil
                self.cleanup()
            }
        }
    }

    /// Immediately stops recording without waiting for final result
    func stop() {
        AppLogger.audio.info("recording phase=stop engine=apple transcript_chars=\(self.transcript.count)")

        isWaitingForFinal = false
        stopContinuation = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

        stopLevelTimer()
    }

    /// Cleanup after final result received
    private func cleanup() {
        AppLogger.audio.info("recording phase=cleanup engine=apple")
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.reset()
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.sampleLevel()
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private var pendingLevel: Float = 0
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
        // simple smoothing
        let smoothed = (level * 0.8) + (pendingLevel * 0.2)
        if abs(smoothed - level) > 0.001 {
            level = smoothed
        }
    }
}
