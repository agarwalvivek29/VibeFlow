//
//  MainView.swift
//  VibeFlow
//
//  Main navigation container with sidebar.
//  Intercepts navigation away from Settings when there are unsaved changes.
//

import SwiftUI
import SwiftData
import os

struct MainView: View {
    @State private var selectedNavigation: NavigationItem? = .dashboard
    @State private var settingsDirty = false
    @State private var showDiscardAlert = false
    @State private var pendingNavigation: NavigationItem? = nil
    @State private var showIssueCenter = false
    @State private var issuePulseActive = false
    @State private var previousIssueCount = 0
    @State private var issuePulseTask: Task<Void, Never>?

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var controller: ConversationController
    @EnvironmentObject var downloadManager: ModelDownloadManager
    @EnvironmentObject var issueCenter: IssueCenter

    // Reference to the current SettingsView so we can call discardChanges()
    // Achieved by storing the view itself — instead we reset via the binding + a discard flag
    @State private var discardSettingsFlag = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Fixed sidebar — intercepts taps when settings has unsaved changes
                SidebarView(selection: sidebarSelection)
                    .frame(width: 260)

                Divider()

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            issueCenterButton
                .padding(.top, 16)
                .padding(.trailing, 18)
                .popover(isPresented: $showIssueCenter, arrowEdge: .top) {
                    IssueCenterPanel(
                        onAction: { issue, action in
                            await handleIssueAction(issue: issue, action: action)
                        },
                        onClose: { showIssueCenter = false }
                    )
                    .environmentObject(issueCenter)
                }
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            AppLogger.app.info("main_view phase=appear action=installing_monitors")
            controller.installGlobalMonitors()
            syncIssues()
            previousIssueCount = issueCenter.activeCount

            #if os(macOS)
            HUDWindowController.shared.initialize(controller: controller, settings: settings)
            #endif
        }
        .onChange(of: controller.speechEngineState) { _ in syncIssues() }
        .onChange(of: controller.textProcessorState) { _ in syncIssues() }
        .onChange(of: controller.processingError) { _ in syncIssues() }
        .onChange(of: issueCenter.activeCount) { count in
            if count > previousIssueCount {
                triggerIssuePulse()
            }
            previousIssueCount = count
        }
        .onDisappear {
            issuePulseTask?.cancel()
            issuePulseTask = nil
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

    private var issueCenterButton: some View {
        Button(action: { showIssueCenter.toggle() }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: issueCenter.activeCount > 0 ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(issueCenter.activeCount > 0 ? .red : .secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Circle())
                    .scaleEffect(issuePulseActive ? 1.12 : 1.0)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(issuePulseActive ? 0.5 : 0), lineWidth: 2)
                            .scaleEffect(issuePulseActive ? 1.24 : 1.0)
                    )

                if issueCenter.activeCount > 0 {
                    Text(issueCenter.activeCount > 99 ? "99+" : "\(issueCenter.activeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 10, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(issueCenter.activeCount > 0 ? "Open issues, \(issueCenter.activeCount) active" : "Open issues, none active")
        .accessibilityHint("Shows centralized error details and actions")
    }

    private func syncIssues() {
        issueCenter.syncModelStates(speech: controller.speechEngineState, text: controller.textProcessorState)
        issueCenter.syncProcessingError(controller.processingError)
    }

    private func triggerIssuePulse() {
        issuePulseTask?.cancel()
        issuePulseTask = Task {
            for _ in 0..<3 {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.16)) {
                        issuePulseActive = true
                    }
                }
                try? await Task.sleep(nanoseconds: 160_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.16)) {
                        issuePulseActive = false
                    }
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            await MainActor.run {
                issuePulseActive = false
            }
        }
    }

    @MainActor
    private func handleIssueAction(issue: IssueCenter.Issue, action: IssueCenter.Action) async {
        switch action {
        case .fixNow:
            try? downloadManager.deleteModel(.slm)
            await controller.rebuildAndPreload(from: settings)
        case .retry:
            await controller.rebuildAndPreload(from: settings)
        case .changeModel:
            selectedNavigation = .settings
            showIssueCenter = false
        }
        syncIssues()
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
        .environmentObject(ModelDownloadManager())
        .environmentObject(IssueCenter())
        .modelContainer(for: TranscriptionEntry.self, inMemory: true)
}
