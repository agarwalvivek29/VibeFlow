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

    // Chunking: SFSpeechRecognizer has an undocumented ~60s limit on continuous audio.
    // We rotate the recognition request before hitting the limit to support unlimited duration.
    private var accumulatedTranscript = ""
    private var currentChunkTranscript = ""
    private var chunkTimer: Timer?
    private var currentContextualTerms: [String] = []
    private let maxChunkDuration: TimeInterval = 50

    // Track recording duration for scaling the final timeout
    private var recordingStartedAt: Date?

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

    func startRecording(contextualTerms: [String] = []) throws {
        AppLogger.audio.info("recording phase=start engine=apple")

        // Ensure clean state with proper cleanup
        if audioEngine.isRunning {
            AppLogger.audio.info("recording phase=cleanup reason=engine_still_running")
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine.reset()
        stopLevelTimer()
        stopChunkTimer()

        // Small delay to ensure I/O thread fully terminates
        Thread.sleep(forTimeInterval: 0.05)

        transcript = ""
        accumulatedTranscript = ""
        currentChunkTranscript = ""
        currentContextualTerms = contextualTerms
        recordingStartedAt = Date()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            AppLogger.audio.error("recording outcome=error engine=apple reason=recognizer_unavailable")
            throw NSError(domain: "AppleSpeechEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

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
            AppLogger.audio.error("recording outcome=error engine=apple reason=no_input_device")
            throw NSError(domain: "AppleSpeechEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "No input device available"])
        }

        // Get device name for logging
        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultDeviceID, &nameAddress, 0, nil, &nameSize, &deviceName)
        AppLogger.audio.info("audio_device selected=\(deviceName as String) device_id=\(defaultDeviceID)")

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

        if sampleRateStatus == noErr && sampleRate > 0 {
            AppLogger.audio.info("audio_device sample_rate=\(Int(sampleRate)) source=native")
        } else {
            sampleRate = 48000 // Fallback
            AppLogger.audio.info("audio_device sample_rate=\(Int(sampleRate)) source=fallback reason=query_failed")
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
                AppLogger.audio.error("audio_device outcome=set_failed status=\(setStatus)")
            }
        }

        // Get the format AFTER setting the device - use the hardware format
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        AppLogger.audio.info("audio_format channels=\(hardwareFormat.channelCount) sample_rate=\(Int(hardwareFormat.sampleRate))")

        // Use nil format to let AVAudioEngine handle format conversion automatically
        // This is more robust for different audio devices (especially Bluetooth)
        let tapFormat: AVAudioFormat?
        if hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 {
            tapFormat = hardwareFormat
            AppLogger.audio.info("audio_tap format=hardware")
        } else {
            tapFormat = nil
            AppLogger.audio.info("audio_tap format=automatic")
        }
        #else
        let inputNode = audioEngine.inputNode
        let tapFormat = inputNode.outputFormat(forBus: 0)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualTerms
        self.recognitionRequest = request

        // Remove any existing tap
        inputNode.removeTap(onBus: 0)

        // Install tap with the compatible format
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.updateLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        AppLogger.audio.info("recording phase=active engine=apple running=\(self.audioEngine.isRunning)")

        startRecognitionTask(with: request, on: recognizer)
        print("✅ Recognition started")

        startLevelTimer()
        startChunkTimer()
    }

    /// Starts a recognition task and wires up the result/error callback.
    private func startRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, on recognizer: SFSpeechRecognizer) {
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result {
                let chunkText = result.bestTranscription.formattedString
                self.currentChunkTranscript = chunkText

                // Combine accumulated chunks with current chunk for display
                let fullText: String
                if self.accumulatedTranscript.isEmpty {
                    fullText = chunkText
                } else {
                    fullText = self.accumulatedTranscript + " " + chunkText
                }
                DispatchQueue.main.async {
                    self.transcript = fullText
                }

                if result.isFinal {
                    // Resume continuation if we're waiting for final (i.e. stopAndWaitForFinal was called)
                    if self.isWaitingForFinal, !self.hasResumedContinuation {
                        self.hasResumedContinuation = true
                        self.isWaitingForFinal = false
                        self.stopContinuation?.resume(returning: fullText)
                        self.stopContinuation = nil
                        self.cleanup()
                    }
                }
            }

            if let error = error {
                AppLogger.audio.error("recognition outcome=error engine=apple error=\(error.localizedDescription)")
                // Resume continuation with whatever we have
                if self.isWaitingForFinal, !self.hasResumedContinuation {
                    self.hasResumedContinuation = true
                    self.isWaitingForFinal = false
                    self.stopContinuation?.resume(returning: self.transcript)
                    self.stopContinuation = nil
                    self.cleanup()
                }
            }
        }
    }

    /// Stops recording and waits for the final transcription result
    /// This ensures all buffered audio is processed and no words are lost
    func stopAndWaitForFinal() async -> String {
        AppLogger.audio.info("recording phase=stop_and_wait engine=apple transcript_chars=\(self.transcript.count)")

        // If not recording, return current transcript
        guard audioEngine.isRunning else {
            AppLogger.audio.info("recording phase=stop_and_wait engine=apple reason=engine_not_running")
            return transcript
        }

        return await withCheckedContinuation { continuation in
            self.hasResumedContinuation = false
            self.stopContinuation = continuation
            self.isWaitingForFinal = true

            // 1. Stop capturing NEW audio
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine.stop()
            self.stopLevelTimer()
            AppLogger.audio.info("recording phase=waiting_for_final engine=apple")
            self.stopChunkTimer()

            // 2. Signal end of audio - recognizer will process remaining buffer
            //    and eventually call back with isFinal = true
            self.recognitionRequest?.endAudio()

            // 3. Set a timeout in case isFinal never comes.
            //    Scale with recording duration: longer recordings need more processing time.
            let recordingDuration = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let timeout = max(5.0, min(recordingDuration * 0.1, 15.0))
            self.recordingStartedAt = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
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
    /// Use this for cleanup or when you don't need the transcript
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
        stopChunkTimer()
        accumulatedTranscript = ""
        currentChunkTranscript = ""
    }

    /// Cleanup after final result received
    private func cleanup() {
        AppLogger.audio.info("recording phase=cleanup engine=apple")
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.reset()
        stopChunkTimer()
    }

    // MARK: - Chunk Rotation

    /// Rotates the recognition request to avoid SFSpeechRecognizer's ~60s time limit.
    /// The audio engine tap keeps running — only the recognizer is restarted.
    private func rotateRecognitionRequest() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("⚠️ Cannot rotate chunk: speech recognizer unavailable")
            return
        }
        guard audioEngine.isRunning else { return }

        print("🔄 Rotating recognition request (chunk limit approaching)")

        // Snapshot the current full transcript as the new accumulated baseline
        accumulatedTranscript = transcript
        currentChunkTranscript = ""

        // Tear down the old recognition task (cancel is fine — we already captured the partial)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Create a fresh request — the audio tap will immediately start feeding it
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.contextualStrings = currentContextualTerms
        self.recognitionRequest = newRequest

        startRecognitionTask(with: newRequest, on: recognizer)
        print("🔄 New recognition chunk started. Accumulated so far: \(accumulatedTranscript.count) chars")
    }

    private func startChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = Timer.scheduledTimer(withTimeInterval: maxChunkDuration, repeats: true) { [weak self] _ in
            self?.rotateRecognitionRequest()
        }
    }

    private func stopChunkTimer() {
        chunkTimer?.invalidate()
        chunkTimer = nil
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
