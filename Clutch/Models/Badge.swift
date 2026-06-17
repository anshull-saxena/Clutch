import Foundation

struct Badge: Identifiable {
    let id:          String
    let name:        String
    let condition:   String  // human-readable trigger
    let iconName:    String
    let colorHex:    String

    static let all: [Badge] = [
        Badge(id: "first_save",      name: "ghost mode",       condition: "First ever save",                    iconName: "ghost",             colorHex: "#EEEDFE"),
        Badge(id: "crisis_averted",  name: "crisis averted",   condition: "Saved at 90%+ volume",              iconName: "flame",             colorHex: "#FCEBEB"),
        Badge(id: "three_am",        name: "3am phantom",      condition: "5+ saves between midnight and 4am", iconName: "moon.stars",        colorHex: "#EAF3DE"),
        Badge(id: "library",         name: "library survivor", condition: "Saved in library mode",             iconName: "building.columns",  colorHex: "#E1F5EE"),
        Badge(id: "discord",         name: "discord guardian", condition: "Saved during an active voice call", iconName: "waveform",          colorHex: "#E6F1FB"),
        Badge(id: "family_safe",     name: "family safe",      condition: "7-day streak with no leaks",       iconName: "house.fill",        colorHex: "#FBEAF0"),
        Badge(id: "hundred",         name: "100 close calls",  condition: "100 total saves",                   iconName: "100",               colorHex: "#FCEBEB"),
        Badge(id: "unbothered",      name: "unbothered",       condition: "30-day clean streak",               iconName: "sunglasses",        colorHex: "#F1EFE8"),
        Badge(id: "goblin",          name: "goblin era",       condition: "Activated goblin mode",             iconName: "flame.fill",        colorHex: "#FAEEDA"),
        Badge(id: "night_owl",       name: "night owl",        condition: "10+ saves after midnight",          iconName: "moon.zzz",          colorHex: "#EEEDFE"),
    ]
}

final class BadgeEngine {

    static let shared = BadgeEngine()
    private init() {}

    private let earnedKey = UDKeys.earnedBadgeIDs

    var earnedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: earnedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: earnedKey) }
    }

    /// Evaluates unearned badges after a save. Returns newly earned badges for the caller to notify on main.
    func evaluate(_ event: ClutchEvent) -> [Badge] {
        let store = EventStore.shared
        var newlyEarned: [Badge] = []
        var earned = earnedIDs

        let needsTotal = !earned.isSuperset(of: ["first_save", "hundred"])
        let needsLateNight = !earned.isSuperset(of: ["three_am", "night_owl"])
        let needsStreak = !earned.isSuperset(of: ["family_safe", "unbothered"])

        let total = needsTotal ? store.totalEventCount() : 0
        let lateNight = needsLateNight ? store.lateNightBadgeCount() : 0
        let streak = needsStreak ? store.currentStreakDays() : 0

        let checks: [(String, Bool)] = [
            ("first_save",     !earned.contains("first_save") && total >= 1),
            ("crisis_averted", !earned.contains("crisis_averted") && event.riskScore >= 90),
            ("three_am",       !earned.contains("three_am") && lateNight >= 5),
            ("library",        !earned.contains("library") && event.mode == .library),
            ("discord",        !earned.contains("discord") && event.frontmostApp.lowercased().contains("discord")),
            ("family_safe",    !earned.contains("family_safe") && streak >= 7),
            ("hundred",        !earned.contains("hundred") && total >= 100),
            ("unbothered",     !earned.contains("unbothered") && streak >= 30),
            ("goblin",         !earned.contains("goblin") && event.mode == .goblin),
            ("night_owl",      !earned.contains("night_owl") && lateNight >= 10),
        ]

        for (id, condition) in checks where condition {
            earned.insert(id)
            if let badge = Badge.all.first(where: { $0.id == id }) {
                newlyEarned.append(badge)
            }
        }

        if !newlyEarned.isEmpty {
            earnedIDs = earned
        }

        return newlyEarned
    }
}
