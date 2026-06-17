import SwiftUI
import UserNotifications

struct NotificationsTab: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    @State private var showGrantedFeedback = false

    var body: some View {
        Form {
            Section(header: Text("Notification Style")) {
                Text("Notifications are always lowercase and short. We don't do clinical 'System alerts'.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Status")) {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }

                if authStatus == .denied {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                        Text("Enable in System Settings → Notifications → Clutch")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if authStatus == .notDetermined {
                    Button {
                        isRequesting = true
                        NotificationManager.shared.requestPermission { granted in
                            isRequesting = false
                            refreshStatus()
                            if granted {
                                showGrantedFeedback = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showGrantedFeedback = false
                                }
                            }
                        }
                    } label: {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Allow Notifications", systemImage: "bell.badge")
                        }
                    }
                }

                if showGrantedFeedback {
                    Label("Notifications enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshStatus)
        .onReceive(NotificationCenter.default.publisher(for: .notificationAuthStatusChanged)) { _ in
            refreshStatus()
        }
    }

    private func refreshStatus() {
        NotificationManager.shared.getAuthorizationStatus { status in
            authStatus = status
        }
    }

    private var statusIcon: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications are enabled"
        case .denied: return "Notifications are disabled"
        case .notDetermined: return "Not yet requested"
        default: return "Unknown"
        }
    }
}
