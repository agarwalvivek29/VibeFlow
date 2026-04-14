//
//  IssueCenterPanel.swift
//  VibeFlow
//
//  Centralized issue panel shown from the global top-right issue button.
//

import SwiftUI

struct IssueCenterPanel: View {
    @EnvironmentObject var issueCenter: IssueCenter

    let onAction: @MainActor (IssueCenter.Issue, IssueCenter.Action) async -> Void
    let onClose: () -> Void

    @State private var runningIssueID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Issues")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(issueCenter.activeCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(issueCenter.activeCount > 0 ? Color.red : Color.secondary.opacity(0.5))
                    .clipShape(Capsule())

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if issueCenter.activeIssues.isEmpty {
                Text("No active issues.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(issueCenter.activeIssues) { issue in
                            issueCard(issue)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 430, height: 320, alignment: .topLeading)
    }

    private func issueCard(_ issue: IssueCenter.Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(issue.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(relativeDateLabel(issue.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text(issue.message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(issue.actions) { action in
                    Button(action.label) {
                        Task {
                            runningIssueID = issue.id
                            await onAction(issue, action)
                            runningIssueID = nil
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(buttonColor(for: action))
                    .cornerRadius(6)
                    .disabled(runningIssueID == issue.id)
                }

                if runningIssueID == issue.id {
                    ProgressView()
                        .scaleEffect(0.55)
                        .padding(.leading, 2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func buttonColor(for action: IssueCenter.Action) -> Color {
        switch action {
        case .fixNow: return .orange
        case .retry: return .red
        case .changeModel: return .secondary
        }
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    IssueCenterPanel(
        onAction: { _, _ in },
        onClose: { }
    )
    .environmentObject(IssueCenter())
}
