// File: CraigOClean-vNext/CraigOClean/UI/Components/PrimaryButton.swift
// Craig-O-Clean - Primary Button Component
// Reusable button with loading state

import SwiftUI

struct PrimaryButton: View {

    // MARK: - Properties

    let title: String
    let icon: String?
    let style: ButtonStyleType
    let isLoading: Bool
    let action: () -> Void

    // MARK: - Initialization

    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyleType = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if let icon = icon {
                    Image(systemName: icon)
                }

                Text(title)
            }
        }
        .buttonStyle(style.buttonStyle)
        .disabled(isLoading)
    }
}

// MARK: - Button Style Type

enum ButtonStyleType {
    case primary
    case secondary
    case destructive

    var buttonStyle: some PrimitiveButtonStyle {
        switch self {
        case .primary:
            return .borderedProminent as! Self.ButtonStyle
        case .secondary:
            return .bordered as! Self.ButtonStyle
        case .destructive:
            return .borderedProminent as! Self.ButtonStyle
        }
    }

    typealias ButtonStyle = BorderedProminentButtonStyle
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            PrimaryButton(title: "Primary", icon: "play.fill") {}
            PrimaryButton(title: "Secondary", style: .secondary) {}
            PrimaryButton(title: "Destructive", icon: "trash", style: .destructive) {}
            PrimaryButton(title: "Loading", isLoading: true) {}
        }
        .padding()
    }
}
#endif
