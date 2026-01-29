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
        let schema = Schema([TranscriptionEntry.self])
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
        let config = settingsInstance.liteLLMConfig ?? LiteLLMConfig(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)
        print("🚀 LiteLLM config ready")
        let llm = LiteLLMClient(config: config)
        print("🚀 LiteLLM client created")
        let controllerInstance = ConversationController(llm: llm, settings: settingsInstance)
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
                .onChange(of: settings.liteLLMBaseURL) {
                    updateLLMClient()
                }
                .onChange(of: settings.liteLLMApiKey) {
                    updateLLMClient()
                }
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

    private func updateLLMClient() {
        guard settings.liteLLMConfig != nil else { return }
        // Note: In a production app, you'd want to handle updating the client more gracefully
        // For now, this requires an app restart to take effect
    }
}
