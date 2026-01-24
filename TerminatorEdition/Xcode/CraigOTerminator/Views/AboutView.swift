import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 10)

            // App Name
            VStack(spacing: 4) {
                Text("Craig-O-Clean")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Terminator Edition")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(maxWidth: 300)

            // Description
            Text("Autonomous AI-Powered System Management for macOS Silicon")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bolt.circle.fill", title: "Autonomous Cleanup", description: "AI-powered system optimization")
                FeatureRow(icon: "person.3.fill", title: "Agent Teams", description: "Multi-agent orchestration")
                FeatureRow(icon: "brain", title: "Local AI", description: "Ollama integration for intelligent decisions")
                FeatureRow(icon: "gauge.high", title: "Real-time Monitoring", description: "Continuous system health tracking")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Credits
            VStack(spacing: 8) {
                Text("Designed for macOS Silicon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text("Made with")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("by Craig Tracey")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("© 2024 Craig-O-Clean. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    AboutView()
        .frame(width: 500, height: 600)
}
