import SwiftUI

struct StatsView: View {
    @ObservedObject private var appState = AppState.shared
    @AppStorage(UDKeys.showRiskScore) private var showRiskScore = true

    var body: some View {
        TabView {
            VStack {
                if appState.isLoadingStats && appState.recentEvents.isEmpty {
                    ProgressView("loading close calls…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.recentEvents.isEmpty {
                    Text("No close calls yet. You're safe.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(appState.recentEvents) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(event.frontmostApp)")
                                    .font(.headline)
                                if showRiskScore {
                                    Text("Volume: \(event.volumePercent)% • Risk: \(event.riskLabel)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Volume: \(event.volumePercent)%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .onAppear {
                appState.loadRecentEvents()
            }
            .tabItem {
                Label("Log", systemImage: "list.bullet")
            }

            BadgeGridView()
                .tabItem {
                    Label("Badges", systemImage: "shield.fill")
                }
        }
        .frame(width: 400, height: 450)
    }
}
