//
//  Theme.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

// MARK: - VibeCaaS Brand Colors

extension Color {
    // MARK: VibeCaaS Brand Colors
    static let vibePrimary = Color(hex: "#6366F1")      // Indigo
    static let vibeSecondary = Color(hex: "#8B5CF6")    // Violet
    static let vibeAccent = Color(hex: "#EC4899")       // Pink
    static let vibeSuccess = Color(hex: "#10B981")      // Emerald
    static let vibeWarning = Color(hex: "#F59E0B")      // Amber
    static let vibeError = Color(hex: "#EF4444")        // Red

    // MARK: Semantic Colors
    static let vibeSafe = vibeSuccess
    static let vibeModerate = vibeWarning
    static let vibeDestructive = vibeError

    // MARK: UI Grays (Adaptive for Light/Dark Mode)
    static let vibeBackground = Color(hex: "#1F2937")   // Dark slate
    static let vibeSurface = Color(hex: "#374151")      // Medium slate
    static let vibeBorder = Color(hex: "#4B5563")       // Light slate

    // Adaptive text colors that work in both light and dark modes
    static let vibeText = Color.primary                  // System adaptive primary text
    static let vibeTextSecondary = Color.secondary       // System adaptive secondary text

    // MARK: Helper for hex initialization
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Risk Class Colors

extension RiskClass {
    /// Get the semantic color for this risk class
    var color: Color {
        switch self {
        case .safe: return .vibeSafe
        case .moderate: return .vibeModerate
        case .destructive: return .vibeDestructive
        }
    }

    /// Get an SF Symbol representing the risk level
    var icon: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .destructive: return "xmark.shield.fill"
        }
    }
}

// MARK: - Typography

enum VibeFont {
    static let title = Font.system(size: 18, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let monospace = Font.system(size: 12, weight: .regular, design: .monospaced)
}

// MARK: - Spacing

enum VibeSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

enum VibeRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - View Modifiers

struct VibeCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(VibeSpacing.md)
            .background(Color.vibeSurface)
            .cornerRadius(VibeRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: VibeRadius.md)
                    .stroke(Color.vibeBorder, lineWidth: 1)
            )
    }
}

struct VibePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.headline)
            .foregroundColor(.white)
            .padding(.horizontal, VibeSpacing.lg)
            .padding(.vertical, VibeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VibeRadius.md)
                    .fill(Color.vibePrimary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct VibeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.body)
            .foregroundColor(.vibePrimary)
            .padding(.horizontal, VibeSpacing.md)
            .padding(.vertical, VibeSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VibeRadius.md)
                    .stroke(Color.vibePrimary, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - View Extensions

extension View {
    func vibeCard() -> some View {
        self.modifier(VibeCardStyle())
    }

    func vibePrimaryButton() -> some View {
        self.buttonStyle(VibePrimaryButtonStyle())
    }

    func vibeSecondaryButton() -> some View {
        self.buttonStyle(VibeSecondaryButtonStyle())
    }
}
