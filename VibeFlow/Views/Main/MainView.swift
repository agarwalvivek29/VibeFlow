//
//  MainView.swift
//  VibeFlow
//
//  Main navigation container with sidebar
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedNavigation: NavigationItem? = .home
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedNavigation)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 350)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 500)
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
        case .home:
            HomeView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView(settings: settings)
        case .none:
            HomeView()
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
