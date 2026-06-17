import Foundation

enum NotificationCopy {

    static func saveMessage(for event: ClutchEvent) -> (title: String, body: String) {
        let vol   = event.volumePercent
        let app   = event.frontmostApp
        let hour  = Calendar.current.component(.hour, from: event.timestamp)
        let isLate = hour >= 23 || hour <= 4

        // Scenario-specific copy
        if app.lowercased().contains("zoom") || app.lowercased().contains("meet") || app.lowercased().contains("teams") {
            return (
                title: "clutch",
                body:  "saved you in the call. no one heard anything. you're good."
            )
        }

        if app.lowercased().contains("discord") {
            return (
                title: "clutch",
                body:  "discord save. those people almost knew ur music taste. on me."
            )
        }

        if isLate && vol > 70 {
            return (
                title: "clutch",
                body:  "3am, \(vol)% volume. bestie. ur family is asleep. handled it."
            )
        }

        if isLate {
            return (
                title: "clutch",
                body:  "close call at \(hourString(hour)). ur sad playlist stays between us."
            )
        }

        if vol >= 90 {
            return (
                title: "clutch",
                body:  "that was \(vol)%. i am the reason you still have friends."
            )
        }

        if vol >= 70 {
            return (
                title: "clutch",
                body:  "caught in 4k? not today. \(app) at \(vol)%. handled."
            )
        }

        // Generic fallbacks
        let fallbacks: [(String, String)] = [
            ("clutch", "bestie i got you."),
            ("clutch", "close call. ur villain arc playlist remains classified."),
            ("clutch", "handled. no one heard anything."),
            ("clutch", "muted in 40ms. crisis averted. carry on."),
        ]
        return fallbacks.randomElement()!
    }

    // Stealth mode: no notification
    static let stealthMessage: (String, String)? = nil

    // 3AM mode extra nudge (appended occasionally)
    static let nudges = [
        "also, drink water.",
        "go to sleep bestie.",
        "ur browser history is safe too btw. that's on you.",
        "water > spotify rn.",
    ]

    private static func hourString(_ hour: Int) -> String {
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let period = hour < 12 ? "AM" : "PM"
        return "\(h)\(period)"
    }
}
