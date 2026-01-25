//
//  ComingSoonView.swift
//  VibeFlow
//
//  Reusable "Coming Soon" placeholder view
//

import SwiftUI

struct ComingSoonView: View {
    let icon: String
    let title: String
    let description: String

    init(icon: String = "sparkles", title: String = "Coming Soon", description: String = "This feature is under development.") {
        self.icon = icon
        self.title = title
        self.description = description
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ComingSoonView(
        icon: "clock.fill",
        title: "History Coming Soon",
        description: "Your transcription history will appear here in a future update."
    )
}
