import Foundation

struct WrappedStats {
    let month:            String    // "June 2026"
    let totalSaves:       Int
    let highestRiskSave:  ClutchEvent?
    let mostSavedFrom:    String    // most common frontmost app
    let lateNightSaves:   Int
    let bestStreak:       Int
    let badgesEarned:     [Badge]
    let headline:         String    // personality-driven summary line

    var shareText: String {
        """
        clutch wrapped — \(month)

        \(totalSaves) crises averted
        highest risk: \(highestRiskSave?.volumePercent ?? 0)% volume
        \(lateNightSaves) saves after midnight
        \(bestStreak) day clean streak
        most saved from: \(mostSavedFrom)

        "i got u" — clutch
        """
    }
}
