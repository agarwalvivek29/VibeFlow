//
//  BrandHeaderView.swift
//  VibeFlow
//
//  Reusable brand header component
//

import SwiftUI

struct BrandHeaderView: View {
    enum Style {
        case compact    // For sidebar/navigation
        case standard   // For page headers
        case banner     // For home page hero
    }

    let style: Style
    var showTagline: Bool = true

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .standard:
            standardView
        case .banner:
            bannerView
        }
    }

    // MARK: - Compact (for sidebar)

    private var compactView: some View {
        HStack(spacing: 8) {
            brandIcon(size: 20)
            Text("VibeFlow")
                .font(.headline)
                .fontWeight(.bold)
        }
    }

    // MARK: - Standard (for page headers)

    private var standardView: some View {
        HStack(spacing: 12) {
            brandIcon(size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("VibeFlow")
                    .font(.title3)
                    .fontWeight(.bold)
                if showTagline {
                    Text("Where Engineers Can Truly Vibe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Banner (for home page hero)

    private var bannerView: some View {
        VStack(spacing: 16) {
            // Icon with subtle glow effect
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 88, height: 88)

                brandIcon(size: 48)
            }

            // Brand name with stylized typography
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("Vibe")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Flow")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Tagline
                Text("Where Engineers Can Truly Vibe")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            // Decorative divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 1)

                Circle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 4, height: 4)

                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 40, height: 1)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Brand Icon

    private func brandIcon(size: CGFloat) -> some View {
        Image(systemName: "waveform.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [.primary, .primary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

#Preview("Compact") {
    BrandHeaderView(style: .compact)
        .padding()
}

#Preview("Standard") {
    BrandHeaderView(style: .standard)
        .padding()
}

#Preview("Banner") {
    BrandHeaderView(style: .banner)
        .padding()
        .frame(width: 500)
}
