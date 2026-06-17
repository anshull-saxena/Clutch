import Foundation
import Combine

enum Mode: String, CaseIterable, Identifiable, Codable {
    case normal      = "normal"
    case threeAM     = "3am"
    case library     = "library"
    case parentZone  = "parent_zone"
    case callMode    = "call_mode"
    case stealth     = "stealth"
    case goblin      = "goblin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:     return "normal"
        case .threeAM:    return "3am mode"
        case .library:    return "library mode"
        case .parentZone: return "parent territory"
        case .callMode:   return "call mode"
        case .stealth:    return "stealth mode"
        case .goblin:     return "goblin mode"
        }
    }

    var description: String {
        switch self {
        case .normal:
            return "mutes on unplug, sends notification, restores on replug."
        case .threeAM:
            return "activates midnight–5am automatically. extra quiet notification. judges you a little."
        case .library:
            return "drops volume to zero before muting. zero sound, ever. for high-stakes public situations."
        case .parentZone:
            return "mutes + sends you a pre-emptive heads up before your next play. ur family is nearby."
        case .callMode:
            return "auto-detects discord/zoom/meet/facetime. mutes system audio AND mic input on unplug."
        case .stealth:
            return "mutes silently. no notification, no sound. no trace. just safety."
        case .goblin:
            return "saves everything, tracks your highest-risk moments, sends a weekly chaos recap."
        }
    }

    var iconName: String {
        switch self {
        case .normal:     return "headphones"
        case .threeAM:    return "moon.stars"
        case .library:    return "building.columns"
        case .parentZone: return "house"
        case .callMode:   return "video"
        case .stealth:    return "eye.slash"
        case .goblin:     return "flame"
        }
    }

    var flavourText: String {
        switch self {
        case .normal:     return "just vibing"
        case .threeAM:    return "bestie go to sleep"
        case .library:    return "the people here don't need to know you"
        case .parentZone: return "ur family is nearby fr fr"
        case .callMode:   return "those 8 people didn't need to hear that"
        case .stealth:    return "no evidence. no trace."
        case .goblin:     return "living ur truth. dangerously."
        }
    }
}

final class ModeManager: ObservableObject {

    static let shared = ModeManager()

    @Published var currentMode: Mode = .normal {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: UDKeys.currentMode)
            if currentMode == .parentZone {
                parentZoneHeadsUpSent = false
            }
        AudioController.shared.updatePlaybackMonitoring(mode: currentMode)
    }
    }

    private var autoTimer: Timer?
    var parentZoneHeadsUpSent = false

    private init() {
        let saved = UserDefaults.standard.string(forKey: UDKeys.currentMode) ?? "normal"
        let initialMode = Mode(rawValue: saved) ?? .normal
        currentMode = initialMode
        startAutoModeCheck()
        AudioController.shared.updatePlaybackMonitoring(mode: initialMode)
    }

    // Auto-switch to 3AM mode between midnight and 5AM, plus check Goblin weekly recap
    private func startAutoModeCheck() {
        autoTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let hour = Calendar.current.component(.hour, from: Date())
            let isLateNight = hour >= 23 || hour < 5

            if isLateNight && self.currentMode == .normal {
                self.currentMode = .threeAM
            } else if !isLateNight && self.currentMode == .threeAM {
                self.currentMode = .normal
            }
            
            self.checkGoblinWeeklyRecap(forceCheck: false)
        }
    }

    // MARK: - Parent Zone Heads Up
    func triggerParentZoneHeadsUpIfNeeded() {
        guard currentMode == .parentZone, !parentZoneHeadsUpSent else { return }
        parentZoneHeadsUpSent = true
        NotificationManager.shared.sendCustomNotification(
            title: "parent territory active",
            body: "heads up: we're ready to instant-mute if they unplug. ur family is nearby."
        )
    }

    // MARK: - Goblin Weekly Recap
    func checkGoblinWeeklyRecap(forceCheck: Bool) {
        guard currentMode == .goblin else { return }

        let now = Date()
        let lastRecap = UserDefaults.standard.object(forKey: UDKeys.lastGoblinRecapDate) as? Date

        if let last = lastRecap {
            let components = Calendar.current.dateComponents([.day], from: last, to: now)
            if let days = components.day, days >= 7 {
                triggerGoblinRecap()
            }
        } else {
            // First time ever: set it to now
            UserDefaults.standard.set(now, forKey: UDKeys.lastGoblinRecapDate)
            if forceCheck {
                // If forced check (e.g. user manually switched to goblin), let's trigger it
                // if they have some saves in database so they see it.
                triggerGoblinRecap()
            }
        }
    }

    private func triggerGoblinRecap() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: UDKeys.lastGoblinRecapDate)

        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let events = EventStore.shared.events(since: oneWeekAgo)

        let totalSaves = events.count
        if totalSaves == 0 {
            NotificationManager.shared.sendCustomNotification(
                title: "goblin weekly recap",
                body: "no close calls this week. you're playing it too safe."
            )
            return
        }

        let highestRiskEvent = events.max(by: { $0.riskScore < $1.riskScore })
        let highestRisk = highestRiskEvent?.riskScore ?? 0
        let mainApp = highestRiskEvent?.frontmostApp ?? "unknown app"

        let body = "goblin weekly recap: \(totalSaves) close calls. peak risk: \(highestRisk)% on \(mainApp). living dangerously."
        NotificationManager.shared.sendCustomNotification(
            title: "goblin weekly recap",
            body: body
        )
    }
}
