import Foundation
import os
import SwiftUI
import SwiftData
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - ModelLoadState

enum ModelLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor
final class ConversationController: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var level: Float = 0
    @Published var isProcessing: Bool = false
    @Published var processingError: String? = nil
    @Published var speechEngineState: ModelLoadState = .idle
    @Published var textProcessorState: ModelLoadState = .idle

    private(set) var speechEngine: any SpeechRecognitionService
    private(set) var textProcessor: (any TextProcessingService)?
    let settings: AppSettings
    var modelContainer: ModelContainer?

    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var previousModifierFlags: NSEvent.ModifierFlags = []
    private var recordingStartedAt: Date?

    init(speechEngine: any SpeechRecognitionService, textProcessor: (any TextProcessingService)?, settings: AppSettings) {
        self.speechEngine = speechEngine
        self.textProcessor = textProcessor
        self.settings = settings
        // Don't request permissions during init - it blocks UI
        // Permissions are now handled by PermissionsHelper in ContentView
        // Key binding changes take effect immediately (read dynamically in event handlers)
    }

    func updateEngines(speech: any SpeechRecognitionService, textProcessor: (any TextProcessingService)?) {
        self.speechEngine = speech
        self.textProcessor = textProcessor
    }

    // MARK: - Engine Factory

    static func buildSpeechEngine(from settings: AppSettings) -> any SpeechRecognitionService {
        switch settings.speechEngine {
        case .apple:
            return AppleSpeechEngine()
        case .whisper:
            return WhisperEngine(modelVariant: settings.whisperModelSize.modelVariant)
        }
    }

    static func buildTextProcessor(from settings: AppSettings) -> (any TextProcessingService)? {
        guard settings.useLLMProcessing else { return nil }
        switch settings.textCleanupEngine {
        case .localSLM:
            return LocalSLMProcessor()
        case .remoteLLM:
            let config = settings.liteLLMConfig ?? LiteLLMConfig(
                baseURL: URL(string: "http://127.0.0.1:4000")!,
                apiKey: nil
            )
            return RemoteLLMProcessor(client: LiteLLMClient(config: config), model: settings.llmModel)
        }
    }

    private func friendlyModelError(_ error: Error, for modelName: String) -> String {
        let raw = error.localizedDescription
        if raw.contains("safetensors.") || raw.contains("model.safetensors") {
            return "The \(modelName) model file is corrupted. Delete the cache in Model Management and retry."
        }
        if raw.contains("No such file") || raw.contains("does not exist") {
            return "The \(modelName) model is missing. Tap Retry to download it."
        }
        if raw.contains("network") || raw.contains("internet") || raw.contains("URLError") {
            return "Download failed. Check your internet connection and retry."
        }
        return "Failed to load \(modelName). Tap Retry or choose a different model."
    }

    /// Rebuild engines and eagerly preload models. Called from the Settings Save button.
    /// Runs async so callers can show a loading indicator while this completes.
    func rebuildAndPreload(from settings: AppSettings) async {
        // Explicitly unload old SLM before replacing — releases Metal/MLX buffers
        if let oldSLM = textProcessor as? LocalSLMProcessor {
            oldSLM.unload()
        }

        let newSpeech = Self.buildSpeechEngine(from: settings)
        let newProcessor = Self.buildTextProcessor(from: settings)

        AppLogger.pipeline.info("engines_rebuild speech=\(settings.speechEngine.rawValue) text=\(settings.textCleanupEngine.rawValue) llm=\(settings.useLLMProcessing)")
        updateEngines(speech: newSpeech, textProcessor: newProcessor)

        if let whisper = newSpeech as? WhisperEngine {
            speechEngineState = .loading
            AppLogger.pipeline.info("model_preload phase=start model=whisper")
            await whisper.loadModel()
            if case .failed(let msg) = whisper.loadState {
                // Remap raw error to a user-friendly message using a synthetic Error
                let syntheticError = NSError(domain: "WhisperEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: msg])
                speechEngineState = .failed(friendlyModelError(syntheticError, for: "Whisper"))
                AppLogger.pipeline.error("model_preload outcome=error model=whisper error=\(msg)")
            } else {
                speechEngineState = whisper.loadState
                AppLogger.pipeline.info("model_preload outcome=success model=whisper")
            }
        } else {
            // Apple Speech is always ready — no download required
            speechEngineState = .loaded
        }

        if let slm = newProcessor as? LocalSLMProcessor {
            textProcessorState = .loading
            AppLogger.pipeline.info("model_preload phase=start model=slm")
            do {
                _ = try await slm.process(text: "Hello", systemPrompt: "Reply with OK")
                textProcessorState = .loaded
                AppLogger.pipeline.info("model_preload outcome=success model=slm")
            } catch {
                textProcessorState = .failed(friendlyModelError(error, for: "AI"))
                AppLogger.pipeline.error("model_preload outcome=error model=slm error=\(error.localizedDescription)")
            }
        } else {
            textProcessorState = newProcessor != nil ? .loaded : .idle
        }
    }

    func installGlobalMonitors() {
        #if os(macOS)
        removeGlobalMonitors()

        // Key binding is read dynamically in each handler so changes take effect immediately

        let handleKeyDown: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let activeKey = self.settings.activeRecordingKey

            // Check if this key matches our recording key (for non-modifier-only bindings)
            if !activeKey.isModifierOnly && self.matchesRecordingKey(event: event, binding: activeKey) && !self.isRecording {
                self.startRecording()
            }

            // Also support modifier-only keys pressed as regular keys (like Right Command keyCode 54)
            if activeKey.isModifierOnly && activeKey.keyCode != 0 && event.keyCode == activeKey.keyCode && !self.isRecording {
                self.startRecording()
            }
        }

        let handleKeyUp: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let activeKey = self.settings.activeRecordingKey

            // For key combos, we only check keyCode on release (user might release modifier first)
            if !activeKey.isModifierOnly && event.keyCode == activeKey.keyCode && self.isRecording {
                Task { await self.stopAndProcess() }
            }

            // Also support modifier-only keys released as regular keys (like Right Command keyCode 54)
            if activeKey.isModifierOnly && activeKey.keyCode != 0 && event.keyCode == activeKey.keyCode && self.isRecording {
                Task { await self.stopAndProcess() }
            }
        }

        let handleFlagsChanged: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            let activeKey = self.settings.activeRecordingKey

            let currentFlags = event.modifierFlags
            let previousFlags = self.previousModifierFlags

            // Only handle modifier-only bindings here
            guard activeKey.isModifierOnly else {
                self.previousModifierFlags = currentFlags
                return
            }

            let wasPressed = self.isModifierPressed(in: previousFlags, for: activeKey)
            let isPressed = self.isModifierPressed(in: currentFlags, for: activeKey)

            if isPressed && !wasPressed && !self.isRecording {
                self.startRecording()
            } else if !isPressed && wasPressed && self.isRecording {
                Task { await self.stopAndProcess() }
            }

            self.previousModifierFlags = currentFlags
        }

        // Global monitors - capture events from OTHER apps
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyDown(event)
            } else if event.type == .flagsChanged {
                handleFlagsChanged(event)
            }
        }
        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: handleKeyUp)

        // Local monitors - capture events from THIS app
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown {
                handleKeyDown(event)
            } else if event.type == .flagsChanged {
                handleFlagsChanged(event)
            }
            return event
        }
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handleKeyUp(event)
            return event
        }
        #endif
    }

    private func matchesRecordingKey(event: NSEvent, binding: KeyBinding) -> Bool {
        #if os(macOS)
        // Check keyCode matches
        guard event.keyCode == binding.keyCode else { return false }

        // Check modifiers match (mask out irrelevant flags)
        let relevantFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]
        let eventModifiers = event.modifierFlags.intersection(relevantFlags)
        let bindingModifiers = NSEvent.ModifierFlags(rawValue: binding.modifiers).intersection(relevantFlags)

        return eventModifiers == bindingModifiers
        #else
        return false
        #endif
    }

    private func isModifierPressed(in flags: NSEvent.ModifierFlags, for binding: KeyBinding) -> Bool {
        #if os(macOS)
        let bindingModifiers = NSEvent.ModifierFlags(rawValue: binding.modifiers)

        // Handle Fn key
        if bindingModifiers.contains(.function) {
            return flags.contains(.function)
        }

        // Handle Command key (need to check keyCode for left vs right)
        if bindingModifiers.contains(.command) {
            // For Right Command (keyCode 54), we check both the modifier flag and that it's not left command
            // For Left Command (keyCode 55), same logic
            // Since flagsChanged doesn't give us keyCode reliably for modifiers,
            // we just check the modifier flag
            return flags.contains(.command)
        }

        // Handle Control key
        if bindingModifiers.contains(.control) {
            return flags.contains(.control)
        }

        // Handle Option key
        if bindingModifiers.contains(.option) {
            return flags.contains(.option)
        }

        return false
        #else
        return false
        #endif
    }

    func removeGlobalMonitors() {
        #if os(macOS)
        if let m = globalKeyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = globalKeyUpMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyUpMonitor { NSEvent.removeMonitor(m) }
        globalKeyDownMonitor = nil
        globalKeyUpMonitor = nil
        localKeyDownMonitor = nil
        localKeyUpMonitor = nil
        previousModifierFlags = []
        #endif
    }

    private func startRecording() {
        guard !isRecording else { return }
        if case .failed(let msg) = speechEngineState {
            AppLogger.pipeline.error("recording outcome=blocked reason=engine_failed error=\(msg)")
            return
        }
        if speechEngineState == .loading || textProcessorState == .loading {
            AppLogger.pipeline.info("recording outcome=blocked reason=model_loading")
            return
        }
        isRecording = true
        recordingStartedAt = Date()
        do {
            // Fetch dictionary terms for contextual recognition
            var terms: [String] = []
            if let container = modelContainer {
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<DictionaryEntry>(
                    predicate: #Predicate<DictionaryEntry> { $0.isEnabled }
                )
                if let entries = try? context.fetch(descriptor) {
                    terms = entries.map(\.term)
                }
            }

            try speechEngine.startRecording(contextualTerms: terms, preferredDeviceUID: settings.preferredInputDeviceUID)
            bindLevel()
            #if os(macOS)
            HUDWindowController.shared.show(controller: self, settings: settings, atBottom: true)
            #endif
        } catch {
            AppLogger.pipeline.error("recording outcome=error phase=start error=\(error.localizedDescription)")
            isRecording = false
        }
    }

    private func bindLevel() {
        // Simple polling since speech engine publishes level
        Task { [weak self] in
            guard let self = self else { return }
            while self.isRecording {
                await MainActor.run { self.level = self.speechEngine.level }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    private func stopRecording() {
        speechEngine.stop()
        isRecording = false
        #if os(macOS)
        // Don't hide - the HUD stays visible in idle state
        // Just update position in case we need to re-center
        HUDWindowController.shared.updatePosition()
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }

    private func performPostTranscriptionAction(_ text: String) {
        #if os(macOS)
        // Always copy to clipboard first
        copyToClipboard(text)

        // Get the configured post-transcription key binding
        guard let keyBinding = settings.postTranscriptionKeyBinding else {
            return // Clipboard only mode
        }

        // Simulate the key press
        simulateKeyPress(keyBinding)
        #endif
    }

    private func simulateKeyPress(_ binding: KeyBinding) {
        #if os(macOS)
        let src = CGEventSource(stateID: .hidSystemState)
        let flags = NSEvent.ModifierFlags(rawValue: binding.modifiers)

        // Build CGEventFlags from the binding
        var cgFlags: CGEventFlags = []
        if flags.contains(.command) {
            cgFlags.insert(.maskCommand)
        }
        if flags.contains(.shift) {
            cgFlags.insert(.maskShift)
        }
        if flags.contains(.option) {
            cgFlags.insert(.maskAlternate)
        }
        if flags.contains(.control) {
            cgFlags.insert(.maskControl)
        }

        // For modifier-only bindings, skip key simulation
        if binding.isModifierOnly { return }

        // Simulate modifier down (if any)
        if flags.contains(.command) {
            let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: true)
            cmdDown?.flags = cgFlags
            cmdDown?.post(tap: .cghidEventTap)
        }

        // Simulate key down/up
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: binding.keyCode, keyDown: true)
        keyDown?.flags = cgFlags
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: binding.keyCode, keyDown: false)
        keyUp?.flags = cgFlags
        keyUp?.post(tap: .cghidEventTap)

        // Simulate modifier up (if any)
        if flags.contains(.command) {
            let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x37, keyDown: false)
            cmdUp?.flags = []
            cmdUp?.post(tap: .cghidEventTap)
        }
        #endif
    }

    // Legacy method for backward compatibility
    private func pasteToFrontmostApp(_ text: String) {
        performPostTranscriptionAction(text)
    }

    func stopAndProcess() async {
        isProcessing = true
        processingError = nil
        defer { isProcessing = false }

        let sessionStart = Date()

        // Grace period: let the audio engine capture the last syllables before stopping.
        // Without this, releasing the key cuts off trailing words.
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        let recordingDuration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil

        let transcript = await speechEngine.stopAndWaitForFinal()
        let engineName = String(describing: type(of: speechEngine))

        isRecording = false
        #if os(macOS)
        HUDWindowController.shared.updatePosition()
        #endif

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let sessionMs = Int(Date().timeIntervalSince(sessionStart) * 1000)
            AppLogger.pipeline.info("session outcome=empty engine=\(engineName) recording_ms=\(Int(recordingDuration * 1000)) session_ms=\(sessionMs)")
            return
        }

        let cleaned = settings.removeFiller ? FillerRemover.removeFiller(from: transcript) : transcript
        let fillersRemoved = transcript.count - cleaned.count

        var processedText = ""
        var usedLLM = false
        var processingMs = 0

        if settings.useLLMProcessing, let processor = textProcessor {
            let processorName = String(describing: type(of: processor))
            AppLogger.pipeline.info("session phase=processing engine=\(engineName) processor=\(processorName) input_chars=\(cleaned.count)")
            let processingStart = Date()
            do {
                processedText = try await processor.process(text: cleaned, systemPrompt: settings.buildSystemPrompt())
                // Model proved functional; clear stale failed state from preload download races.
                if case .failed = textProcessorState { textProcessorState = .loaded }
                processingMs = Int(Date().timeIntervalSince(processingStart) * 1000)
                pasteToFrontmostApp(processedText)
                usedLLM = true
            } catch {
                processingMs = Int(Date().timeIntervalSince(processingStart) * 1000)
                AppLogger.pipeline.error("session phase=processing_failed engine=\(engineName) error=\(error.localizedDescription) processing_ms=\(processingMs)")
                let errMsg = friendlyModelError(error, for: "AI")
                processingError = errMsg
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if self?.processingError == errMsg { self?.processingError = nil }
                }
                pasteToFrontmostApp(cleaned)
                processedText = cleaned
            }
        } else {
            pasteToFrontmostApp(cleaned)
            processedText = cleaned
        }

        let wordCount = processedText.split(separator: " ").count
        let sessionMs = Int(Date().timeIntervalSince(sessionStart) * 1000)

        // Wide session event — one structured log per recording session
        AppLogger.pipeline.info("session outcome=success engine=\(engineName) recording_ms=\(Int(recordingDuration * 1000)) words=\(wordCount) chars=\(processedText.count) fillers_removed=\(fillersRemoved) llm=\(usedLLM) processing_ms=\(processingMs) session_ms=\(sessionMs)")

        saveToHistory(
            rawTranscript: transcript,
            processedText: processedText,
            usedLLM: usedLLM,
            duration: recordingDuration
        )
    }

    private func saveToHistory(rawTranscript: String, processedText: String, usedLLM: Bool, duration: TimeInterval) {
        guard let modelContainer = modelContainer else { return }

        let wordCount = processedText.split(separator: " ").count
        let activeModel: String
        if !usedLLM {
            activeModel = ""
        } else if settings.textCleanupEngine == .localSLM {
            activeModel = "Qwen2.5-0.5B"
        } else {
            activeModel = settings.llmModel
        }
        let entry = TranscriptionEntry(
            rawTranscript: rawTranscript,
            processedText: processedText,
            timestamp: Date(),
            llmModel: activeModel,
            writingStyle: settings.writingStyle.rawValue,
            usedLLMProcessing: usedLLM,
            wordCount: wordCount,
            durationSeconds: duration
        )

        let context = ModelContext(modelContainer)
        context.insert(entry)
        try? context.save()
    }

    // TEST METHODS - For debugging
    func testStartRecording() {
        startRecording()
    }

    func testStopRecording() async {
        await stopAndProcess()
    }
}
