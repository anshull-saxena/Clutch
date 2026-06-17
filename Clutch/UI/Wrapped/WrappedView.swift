import SwiftUI

struct WrappedContainerView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        Group {
            if appState.isLoadingWrapped || appState.wrappedStats == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("loading your wrapped…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 380, height: 300)
            } else if let stats = appState.wrappedStats {
                WrappedView(stats: stats)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.wrappedStats != nil)
        .onAppear {
            appState.loadWrappedStats()
        }
    }
}

struct WrappedView: View {

    let stats: WrappedStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(stats.month)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Text(stats.headline)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.bottom, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WrappedStatCard(label: "crises averted", value: "\(stats.totalSaves)")
                WrappedStatCard(label: "highest risk save", value: "\(stats.highestRiskSave?.volumePercent ?? 0)%")
                WrappedStatCard(label: "saves after midnight", value: "\(stats.lateNightSaves)")
                WrappedStatCard(label: "clean day streak", value: "\(stats.bestStreak) days")
            }
            .padding(.bottom, 20)

            if !stats.mostSavedFrom.isEmpty {
                Text("most saves while in \(stats.mostSavedFrom)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }

            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(stats.shareText, forType: .string)
            } label: {
                Label("copy to share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(width: 380)
    }
}

struct WrappedStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
