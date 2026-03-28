//
//  MainView.swift
//  VibeFlow
//
//  Main navigation container with sidebar.
//  Intercepts navigation away from Settings when there are unsaved changes.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var selectedNavigation: NavigationItem? = .dashboard
    @State private var settingsDirty = false
    @State private var showDiscardAlert = false
    @State private var pendingNavigation: NavigationItem? = nil

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController

    // Reference to the current SettingsView so we can call discardChanges()
    // Achieved by storing the view itself — instead we reset via the binding + a discard flag
    @State private var discardSettingsFlag = false

    var body: some View {
        HStack(spacing: 0) {
            // Fixed sidebar — intercepts taps when settings has unsaved changes
            SidebarView(selection: sidebarSelection)
                .frame(width: 260)

            Divider()

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            print("📱 MainView onAppear - ensuring monitors are installed...")
            controller.installGlobalMonitors()

            #if os(macOS)
            HUDWindowController.shared.initialize(controller: controller, settings: settings)
            #endif
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                discardSettingsFlag = true
                settingsDirty = false
                if let pending = pendingNavigation {
                    selectedNavigation = pending
                    pendingNavigation = nil
                }
            }
            Button("Keep Editing", role: .cancel) {
                pendingNavigation = nil
            }
        } message: {
            Text("You have unsaved settings changes. If you leave now, they will be discarded.")
        }
    }

    /// A proxy binding that intercepts nav changes when Settings is dirty.
    private var sidebarSelection: Binding<NavigationItem?> {
        Binding(
            get: { selectedNavigation },
            set: { newValue in
                guard newValue != selectedNavigation else { return }
                if selectedNavigation == .settings && settingsDirty {
                    // Hold the requested nav, show the alert instead
                    pendingNavigation = newValue
                    showDiscardAlert = true
                } else {
                    selectedNavigation = newValue
                }
            }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedNavigation {
        case .dashboard:
            DashboardView(selectedNavigation: $selectedNavigation)
        case .history:
            HistoryView()
        case .dictionary:
            DictionaryView()
        case .settings:
            SettingsView(settings: settings, isDirty: $settingsDirty)
                .id(discardSettingsFlag) // re-init the view to reset draft when discarding
        case .none:
            DashboardView(selectedNavigation: $selectedNavigation)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppSettings())
        .environmentObject(ConversationController(
            speechEngine: AppleSpeechEngine(),
            textProcessor: nil,
            settings: AppSettings()
        ))
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
