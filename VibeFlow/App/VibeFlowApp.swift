//
//  VibeFlowApp.swift
//  VibeFlow
//
//  Created by Vivek Agarwal on 14/01/26.
//

import SwiftUI
import SwiftData
import os
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
            AppLogger.app.error("swiftdata_migration outcome=failed error=\(error.localizedDescription) action=recreating_store")
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
        AppLogger.app.info("startup phase=init")
        let settingsInstance = AppSettings()
        AppLogger.app.info("startup phase=settings_loaded speech_engine=\(settingsInstance.speechEngine.rawValue) text_engine=\(settingsInstance.textCleanupEngine.rawValue) llm_enabled=\(settingsInstance.useLLMProcessing)")

        let speechEngine = ConversationController.buildSpeechEngine(from: settingsInstance)
        let textProcessor = ConversationController.buildTextProcessor(from: settingsInstance)

        let controllerInstance = ConversationController(speechEngine: speechEngine, textProcessor: textProcessor, settings: settingsInstance)
        _settings = StateObject(wrappedValue: settingsInstance)
        _controller = StateObject(wrappedValue: controllerInstance)
        AppLogger.app.info("startup phase=complete")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(controller)
                .preferredColorScheme(settings.appColorScheme.swiftUIValue)
                .frame(minWidth: 1000, minHeight: 650)
                .onAppear {
                    let hasAccessibility = PermissionsHelper.checkAccessibilityPermissions()
                    let hasMicrophone = PermissionsHelper.checkMicrophonePermission()
                    let hasSpeech = PermissionsHelper.checkSpeechRecognitionPermission()

                    AppLogger.app.info("permissions accessibility=\(hasAccessibility) microphone=\(hasMicrophone) speech_recognition=\(hasSpeech)")

                    if !hasAccessibility {
                        AppLogger.app.error("permission_missing type=accessibility impact=global_hotkeys_disabled")
                    }
                    if !hasMicrophone {
                        AppLogger.app.error("permission_missing type=microphone")
                    }
                    if !hasSpeech {
                        AppLogger.app.error("permission_missing type=speech_recognition")
                    }

                    controller.installGlobalMonitors()
                    controller.modelContainer = sharedModelContainer

                    // Preload models on launch (settings are already committed at this point)
                    Task {
                        await controller.rebuildAndPreload(from: settings)
                    }

                    #if os(macOS)
                    AppLogger.app.info("hud phase=initializing")
                    HUDWindowController.shared.initialize(controller: controller, settings: settings)
                    #endif

                    AppLogger.app.info("startup phase=on_appear_complete")
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .windowSize) {
                Button("Enter Full Screen") {
                    NSApp.mainWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }
        }
    }
}
