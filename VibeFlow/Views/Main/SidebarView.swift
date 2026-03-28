//
//  SidebarView.swift
//  VibeFlow
//
//  Minimal sidebar
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            navigationItems
            Spacer()
            statusFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 0) {
                Text("Vibe")
                    .font(.system(size: 18, weight: .semibold))
                Text("Flow")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 40)
    }

    private var navigationItems: some View {
        VStack(spacing: 4) {
            ForEach(NavigationItem.allCases) { item in
                navButton(for: item)
            }
        }
    }

    private func navButton(for item: NavigationItem) -> some View {
        Button(action: { selection = item }) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 15))
                    .foregroundColor(selection == item ? Color(red: 0.357, green: 0.310, blue: 0.914) : .secondary)
                    .frame(width: 18)

                Text(item.label)
                    .font(.system(size: 14))
                    .foregroundColor(selection == item ? .primary : .secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(selection == item ? Color(red: 0.357, green: 0.310, blue: 0.914).opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var statusFooter: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(controller.isRecording ? Color.red : Color(red: 0.357, green: 0.310, blue: 0.914))
                .frame(width: 7, height: 7)

            Text(controller.isRecording ? "Recording" : "Ready")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .environmentObject(ConversationController(
            speechEngine: AppleSpeechEngine(),
            textProcessor: nil,
            settings: AppSettings()
        ))
        .frame(width: 260, height: 600)
}
