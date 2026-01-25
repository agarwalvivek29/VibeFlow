//
//  StatCard.swift
//  VibeFlow
//
//  Reusable stat display component
//

import SwiftUI

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    var iconColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        StatCard(icon: "bolt.fill", value: "Direct Paste", label: "Processing Mode", iconColor: .yellow)
        StatCard(icon: "checkmark.circle.fill", value: "Ready", label: "Status", iconColor: .green)
    }
    .padding()
}
