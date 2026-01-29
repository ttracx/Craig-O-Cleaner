// File: CraigOClean-vNext/CraigOClean/UI/Components/SectionCard.swift
// Craig-O-Clean - Section Card Component
// Reusable card container for dashboard sections

import SwiftUI

struct SectionCard<Content: View>: View {

    // MARK: - Properties

    let content: Content

    // MARK: - Initialization

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Section Card with Header

struct SectionCardWithHeader<Content: View>: View {

    let title: String
    let icon: String?
    let content: Content

    init(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(.accentColor)
                    }
                    Text(title)
                        .font(.headline)
                }

                content
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {

    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        SectionCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SectionCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SectionCard {
                Text("Basic Section Card")
            }

            SectionCardWithHeader(title: "With Header", icon: "star") {
                Text("Content goes here")
            }

            StatCard(
                title: "Files Cleaned",
                value: "1,234",
                icon: "trash.fill",
                color: .green
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
