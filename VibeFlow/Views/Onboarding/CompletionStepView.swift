//
//  CompletionStepView.swift
//  VibeFlow
//
//  Final step of onboarding - completion
//

import SwiftUI

struct CompletionStepView: View {
    let onComplete: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

            // Header
            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("VibeFlow is ready to use")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Quick reminder
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Reminder")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Image(systemName: "fn")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .frame(width: 48, height: 48)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Press and hold Fn key")
                            .font(.headline)

                        Text("Speak naturally, then release to transcribe and paste")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(.horizontal, 60)

            Spacer()

            // Start button
            Button(action: onComplete) {
                Text("Start Using VibeFlow")
                    .font(.headline)
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding()
        .onAppear {
            // Delay the animation slightly for effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCheckmark = true
            }
        }
    }
}

#Preview {
    CompletionStepView(onComplete: {})
}
