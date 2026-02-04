//
//  UpgradeView.swift
//  Craig-O-Clean Lite
//
//  Beautiful upgrade screen with Stripe integration
//

import SwiftUI

struct UpgradeView: View {
    @StateObject private var upgradeService = UpgradeService()
    @State private var email = ""
    @State private var showingSuccess = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Upgrade to Full Version")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Unlock all features and supercharge your Mac")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Pricing Card
                    VStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$19")
                                .font(.system(size: 48, weight: .bold))
                            Text(".99")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .offset(y: -8)
                        }

                        Text("One-time payment • Lifetime access")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("No subscription • Free updates forever")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)

                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What You'll Get")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(UpgradeService.Pricing.features, id: \.self) { feature in
                            FeatureRow(feature: feature)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)

                    // Email Input (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("your@email.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                    }

                    // Upgrade Button
                    Button(action: handleUpgrade) {
                        HStack {
                            if upgradeService.isProcessingUpgrade {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }

                            Text(upgradeService.isProcessingUpgrade ? "Processing..." : "Upgrade Now")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(upgradeService.isProcessingUpgrade)

                    // Error Message
                    if let error = upgradeService.upgradeError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Trust Badges
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            TrustBadge(icon: "lock.shield", text: "Secure Payment")
                            TrustBadge(icon: "arrow.clockwise", text: "30-Day Refund")
                            TrustBadge(icon: "envelope.badge", text: "Email Support")
                        }

                        Text("Powered by Stripe • 256-bit SSL encryption")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Maybe Later") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Compare Versions") {
                    openComparisonDocs()
                }
                .buttonStyle(.link)
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .alert("Upgrade Successful! 🎉", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Craig-O-Clean Full is downloading. Check your Downloads folder and install the full version!")
        }
    }

    private func handleUpgrade() {
        upgradeService.startUpgradeFlow(email: email.isEmpty ? nil : email)

        // Monitor for success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if !upgradeService.isProcessingUpgrade && upgradeService.upgradeError == nil {
                showingSuccess = true
            }
        }
    }

    private func openComparisonDocs() {
        if let url = URL(string: "https://docs.neuralquantum.ai/craig-o-clean/comparison") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct FeatureRow: View {
    let feature: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))

            Text(feature)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct TrustBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    UpgradeView()
}
