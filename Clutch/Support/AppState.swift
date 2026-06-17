import Foundation
import Combine

extension Notification.Name {
    static let clutchEventSaved = Notification.Name("ClutchEventSaved")
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var monthSummary = MonthSummary(
        totalSaves: 0, highestRisk: 0, lateNightSaves: 0, streakDays: 0
    )
    @Published private(set) var recentEvents: [ClutchEvent] = []
    @Published private(set) var earnedBadgeIDs: Set<String> = []
    @Published private(set) var isLoadingStats = false
    @Published private(set) var wrappedStats: WrappedStats?
    @Published private(set) var isLoadingWrapped = false

    private let workQueue = DispatchQueue(label: "com.clutch.appstate", qos: .userInitiated)

    private init() {
        earnedBadgeIDs = BadgeEngine.shared.earnedIDs
        refreshMonthSummary()
    }

    func loadRecentEvents() {
        guard !isLoadingStats else { return }
        isLoadingStats = true

        workQueue.async { [weak self] in
            let events = EventStore.shared.recent(limit: 50)
            DispatchQueue.main.async {
                guard let self else { return }
                self.recentEvents = events
                self.isLoadingStats = false
            }
        }
    }

    func refreshMonthSummary() {
        workQueue.async {
            let summary = EventStore.shared.thisMonthSummary()
            DispatchQueue.main.async {
                AppState.shared.monthSummary = summary
            }
        }
    }

    func refreshEarnedBadges() {
        earnedBadgeIDs = BadgeEngine.shared.earnedIDs
    }

    func handleEventSaved() {
        refreshMonthSummary()
        refreshEarnedBadges()

        workQueue.async {
            let events = EventStore.shared.recent(limit: 50)
            DispatchQueue.main.async {
                AppState.shared.recentEvents = events
            }
        }
    }

    func loadWrappedStats() {
        guard !isLoadingWrapped else { return }
        isLoadingWrapped = true
        wrappedStats = nil

        workQueue.async {
            let stats = EventStore.shared.buildWrappedStats()
            DispatchQueue.main.async {
                AppState.shared.wrappedStats = stats
                AppState.shared.isLoadingWrapped = false
            }
        }
    }
}
