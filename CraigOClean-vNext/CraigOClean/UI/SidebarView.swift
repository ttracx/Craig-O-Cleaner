// File: CraigOClean-vNext/CraigOClean/UI/SidebarView.swift
// Craig-O-Clean - Sidebar View
// Navigation sidebar with tab selection

import SwiftUI

struct SidebarView: View {

    // MARK: - Properties

    @Binding var selectedTab: NavigationTab
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var logStore: LogStore

    // MARK: - Body

    var body: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(NavigationTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            HStack {
                                Text(tab.rawValue)

                                Spacer()

                                // Show badge for logs if there are errors
                                if tab == .logs && logStore.errorCount > 0 {
                                    Text("\(logStore.errorCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                }
                            }
                        } icon: {
                            Image(systemName: tab.icon)
                        }
                    }
                }
            } header: {
                Text("Navigation")
            }

            Section {
                editionInfoView
            } header: {
                Text("Edition")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Craig-O-Clean")
        .frame(minWidth: 200)
    }

    // MARK: - Edition Info View

    private var editionInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: environment.isPro ? "crown.fill" : "crown")
                    .foregroundColor(environment.isPro ? .yellow : .secondary)

                Text(environment.edition.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Text(environment.edition.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if environment.isLite {
                Link(destination: URL(string: "https://craigosoft.com/pro")!) {
                    Text("Upgrade to Pro")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedTab: .constant(.dashboard))
            .environmentObject(AppEnvironment.shared)
            .environmentObject(LogStore())
            .frame(width: 250)
    }
}
#endif
