//
//  OnboardingContainerView.swift
//  VibeFlow
//
//  Container view for the onboarding flow
//

import SwiftUI

struct OnboardingContainerView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0
    @EnvironmentObject var settings: AppSettings

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            // Content
            TabView(selection: $currentStep) {
                WelcomeStepView(onContinue: { nextStep() })
                    .tag(0)

                PermissionsStepView(onContinue: { nextStep() }, onSkip: { nextStep() })
                    .tag(1)

                ConfigurationStepView(onContinue: { nextStep() })
                    .tag(2)

                CompletionStepView(onComplete: onComplete)
                    .tag(3)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: currentStep)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func nextStep() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }
}

#Preview {
    OnboardingContainerView(onComplete: {})
        .environmentObject(AppSettings())
}
