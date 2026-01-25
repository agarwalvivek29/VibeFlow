//
//  RootView.swift
//  VibeFlow
//
//  Root view that handles onboarding vs main app routing
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingContainerView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)),
            settings: AppSettings()
        ))
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
