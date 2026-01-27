// MARK: - PermissionNotificationBanner.swift
// Craig-O-Clean - Permission Grant Notification Banner
// Displays toast notifications when browser permissions are granted

import SwiftUI

// MARK: - Permission Notification Banner

struct PermissionNotificationBanner: View {
    @ObservedObject var permissionManager: BrowserPermissionManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(permissionManager.pendingNotifications) { notification in
                NotificationCard(
                    notification: notification,
                    onDismiss: {
                        permissionManager.dismissNotification(id: notification.id)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: permissionManager.pendingNotifications.count)
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: PermissionGrantNotification
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.browserName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Automation enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Permission Statistics View

struct PermissionStatisticsView: View {
    let statistics: PermissionStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permission Status")
                .font(.headline)

            HStack(spacing: 20) {
                StatBadge(
                    title: "Granted",
                    value: "\(statistics.grantedCount)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )

                StatBadge(
                    title: "Pending",
                    value: "\(statistics.deniedCount)",
                    color: .orange,
                    icon: "clock.circle.fill"
                )

                if statistics.recentGrants > 0 {
                    StatBadge(
                        title: "Recent",
                        value: "\(statistics.recentGrants)",
                        color: .blue,
                        icon: "star.circle.fill"
                    )
                }
            }

            // Progress bar
            if statistics.totalBrowsers > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Overall Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(statistics.grantedPercentage))%")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * (statistics.grantedPercentage / 100),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionNotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PermissionNotificationBanner(
                permissionManager: {
                    let manager = BrowserPermissionManager()
                    manager.pendingNotifications = [
                        PermissionGrantNotification(browserName: "Safari", timestamp: Date()),
                        PermissionGrantNotification(browserName: "Google Chrome", timestamp: Date())
                    ]
                    return manager
                }()
            )
            .frame(maxWidth: 400)

            Divider()

            PermissionStatisticsView(
                statistics: PermissionStatistics(
                    totalBrowsers: 5,
                    grantedCount: 3,
                    deniedCount: 2,
                    recentGrants: 1
                )
            )
            .frame(width: 400)
        }
        .padding()
    }
}
#endif
