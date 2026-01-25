//
//  SidebarView.swift
//  VibeFlow
//
//  Sidebar navigation for the main app
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        List(NavigationItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.label, systemImage: item.icon)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            brandHeader
        }
        .safeAreaInset(edge: .bottom) {
            statusFooter
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text("Vibe")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Flow")
                        .font(.system(size: 16, weight: .light, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var statusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isRecording ? Color.red : Color.green)
                .frame(width: 8, height: 8)

            Text(controller.isRecording ? "Recording..." : "Ready")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

#Preview {
    SidebarView(selection: .constant(.home))
        .environmentObject(ConversationController(
            llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)),
            settings: AppSettings()
        ))
        .frame(width: 220)
}
