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

        let speechEngine = ConversationController.buildSpeechEngine(from: settingsInstance)
        print("🚀 Speech engine created: \(settingsInstance.speechEngine.rawValue)")

        let textProcessor = ConversationController.buildTextProcessor(from: settingsInstance)
        print("🚀 Text processor created: \(settingsInstance.textCleanupEngine.rawValue)")

        let controllerInstance = ConversationController(speechEngine: speechEngine, textProcessor: textProcessor, settings: settingsInstance)
        print("🚀 ConversationController created")
        _settings = StateObject(wrappedValue: settingsInstance)
        _controller = StateObject(wrappedValue: controllerInstance)
        print("🚀 VibeFlow init complete")
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

                    let hasAccessibility = PermissionsHelper.checkAccessibilityPermissions()
                    let hasMicrophone = PermissionsHelper.checkMicrophonePermission()
                    let hasSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

                    print("📊 Permission Status:")
                    print("   🔐 Accessibility: \(hasAccessibility)")
                    print("   🎤 Microphone: \(hasMicrophone)")
                    print("   🗣️ Speech Recognition: \(hasSpeech)")

                    if !hasAccessibility {
                        print("⚠️ WARNING: Accessibility permission NOT granted! Global hotkeys will NOT work!")
                    }
                    if !hasMicrophone {
                        print("⚠️ WARNING: Microphone permission NOT granted!")
                    }
                    if !hasSpeech {
                        print("⚠️ WARNING: Speech Recognition permission NOT granted!")
                    }

                    print("📱 Installing global monitors now...")
                    controller.installGlobalMonitors()
                    controller.modelContainer = sharedModelContainer

                    // Preload models on launch (settings are already committed at this point)
                    Task {
                        await controller.rebuildAndPreload(from: settings)
                    }

                    #if os(macOS)
                    print("📱 Initializing HUD notch...")
                    HUDWindowController.shared.initialize(controller: controller, settings: settings)
                    #endif

                    print("📱 onAppear complete")
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
