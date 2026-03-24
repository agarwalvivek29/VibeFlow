//
//  RootView.swift
//  VibeFlow
//
//  Root view that routes to the main app
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        MainView()
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            speechEngine: AppleSpeechEngine(),
            textProcessor: nil,
            settings: AppSettings()
        ))
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
