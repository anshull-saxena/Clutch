import SwiftUI

struct BadgeGridView: View {
    @ObservedObject private var appState = AppState.shared
    let badges: [Badge] = Badge.all

    let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(badges) { badge in
                    let isEarned = appState.earnedBadgeIDs.contains(badge.id)

                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isEarned ? Color(hex: badge.colorHex) : Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)

                            Image(systemName: badge.iconName)
                                .font(.title)
                                .foregroundColor(isEarned ? .primary : .secondary)
                        }

                        Text(badge.name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(isEarned ? .primary : .secondary)
                    }
                    .opacity(isEarned ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.25), value: isEarned)
                    .help(badge.condition)
                }
            }
            .padding()
        }
        .onAppear {
            appState.refreshEarnedBadges()
        }
    }
}
