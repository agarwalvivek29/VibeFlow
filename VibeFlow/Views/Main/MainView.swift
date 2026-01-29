//
//  MainView.swift
//  VibeFlow
//
//  Main navigation container with sidebar
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedNavigation: NavigationItem? = .dashboard
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        HStack(spacing: 0) {
            // Fixed sidebar
            SidebarView(selection: $selectedNavigation)
                .frame(width: 260)

            Divider()

            // Detail view
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1000, height: 650)
        .background(Color.white)
        .onAppear {
            // Ensure monitors are installed when MainView appears
            // (handles case where onboarding was just completed)
            print("📱 MainView onAppear - ensuring monitors are installed...")
            controller.installGlobalMonitors()

            #if os(macOS)
            HUDWindowController.shared.initialize(controller: controller, settings: settings)
            #endif
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedNavigation {
        case .dashboard:
            DashboardView(selectedNavigation: $selectedNavigation)
        case .history:
            HistoryView()
        case .settings:
            SettingsView(settings: settings)
        case .none:
            DashboardView(selectedNavigation: $selectedNavigation)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)),
            settings: AppSettings()
        ))
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
