//
//  VibeFlowApp.swift
//  VibeFlow
//
//  Created by Vivek Agarwal on 14/01/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct VibeFlowApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var controller: ConversationController

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TranscriptionEntry.self, DictionaryEntry.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema migration failed — delete old store and retry
            print("⚠️ SwiftData migration failed, recreating store: \(error)")
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // Also remove journal/wal files
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    init() {
        print("🚀 VibeFlow initializing...")
        let settingsInstance = AppSettings()
        print("🚀 Settings loaded")

        let speechEngine: any SpeechRecognitionService = Self.buildSpeechEngine(from: settingsInstance)
        print("🚀 Speech engine created: \(settingsInstance.speechEngine.rawValue)")

        let textProcessor: (any TextProcessingService)? = Self.buildTextProcessor(from: settingsInstance)
        print("🚀 Text processor created: \(settingsInstance.textCleanupEngine.rawValue)")

        let controllerInstance = ConversationController(speechEngine: speechEngine, textProcessor: textProcessor, settings: settingsInstance)
        print("🚀 ConversationController created")
        _settings = StateObject(wrappedValue: settingsInstance)
        _controller = StateObject(wrappedValue: controllerInstance)
        print("🚀 VibeFlow init complete")
    }

    private static func buildSpeechEngine(from settings: AppSettings) -> any SpeechRecognitionService {
        switch settings.speechEngine {
        case .apple:
            return AppleSpeechEngine()
        case .whisper:
            return WhisperEngine(modelVariant: settings.whisperModelSize.modelVariant)
        }
    }

    private static func buildTextProcessor(from settings: AppSettings) -> (any TextProcessingService)? {
        guard settings.useLLMProcessing else { return nil }
        switch settings.textCleanupEngine {
        case .localSLM:
            return LocalSLMProcessor()
        case .remoteLLM:
            let config = settings.liteLLMConfig ?? LiteLLMConfig(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)
            return RemoteLLMProcessor(client: LiteLLMClient(config: config), model: settings.llmModel)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(controller)
                .preferredColorScheme(.light)
                .background(Color.white)
                .frame(minWidth: 1000, minHeight: 650)
                .onAppear {
                    print("📱 App onAppear - checking permissions before installing monitors...")

                    // Check all permissions
                    let hasAccessibility = PermissionsHelper.checkAccessibilityPermissions()
                    let hasMicrophone = PermissionsHelper.checkMicrophonePermission()
                    let hasSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

                    print("📊 Permission Status:")
                    print("   🔐 Accessibility: \(hasAccessibility)")
                    print("   🎤 Microphone: \(hasMicrophone)")
                    print("   🗣️ Speech Recognition: \(hasSpeech)")

                    if !hasAccessibility {
                        print("⚠️ WARNING: Accessibility permission NOT granted! Global hotkeys will NOT work!")
                        print("⚠️ You MUST enable VibeFlow in System Settings → Privacy & Security → Accessibility")
                    }

                    if !hasMicrophone {
                        print("⚠️ WARNING: Microphone permission NOT granted!")
                    }

                    if !hasSpeech {
                        print("⚠️ WARNING: Speech Recognition permission NOT granted!")
                    }

                    print("📱 Installing global monitors now...")
                    controller.installGlobalMonitors()

                    // Pass the model context to the controller
                    controller.modelContainer = sharedModelContainer

                    #if os(macOS)
                    // Initialize the always-visible HUD notch
                    print("📱 Initializing HUD notch...")
                    HUDWindowController.shared.initialize(controller: controller, settings: settings)
                    #endif

                    print("📱 onAppear complete")
                }
                .onChange(of: settings.speechEngine) { rebuildEngines() }
                .onChange(of: settings.whisperModelSize) { rebuildEngines() }
                .onChange(of: settings.textCleanupEngine) { rebuildEngines() }
                .onChange(of: settings.useLLMProcessing) { rebuildEngines() }
                .onChange(of: settings.liteLLMBaseURL) { rebuildEngines() }
                .onChange(of: settings.liteLLMApiKey) { rebuildEngines() }
                .onChange(of: settings.llmModel) { rebuildEngines() }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 650)
        .commands {
            // Remove default window commands for cleaner look
            CommandGroup(replacing: .newItem) { }
        }
    }

    private func rebuildEngines() {
        let newSpeech = Self.buildSpeechEngine(from: settings)
        let newProcessor = Self.buildTextProcessor(from: settings)
        print("🔄 Engines updated: speech=\(settings.speechEngine.rawValue), text=\(settings.textCleanupEngine.rawValue), enabled=\(settings.useLLMProcessing)")
        controller.updateEngines(speech: newSpeech, textProcessor: newProcessor)
    }
}
