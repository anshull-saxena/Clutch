import AppKit
import Combine

final class ModeSuggester: NSObject {

    static let shared = ModeSuggester()

    @Published private(set) var suggestedMode: Mode?

    private let appModeRules: [String: Mode] = [
        "us.zoom.xos":                .callMode,
        "com.apple.FaceTime":         .callMode,
        "com.microsoft.teams":        .callMode,
        "com.hnc.Discord":            .callMode,
        "com.skype.skype":            .callMode,
        "com.tinyspeck.slackmacgap":  .callMode,
        "org.videolan.vlc":           .library,
        "com.apple.QuickTimePlayerX": .library,
        "com.spotify.client":         .library,
        "com.apple.Music":            .library,
        "com.apple.TV":               .library,
        "com.apple.Keynote":          .stealth,
        "com.microsoft.Powerpoint":   .stealth,
    ]

    private var lastSuggestionTimes: [String: Date] = [:]
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Clear suggestion times when the user changes mode
        ModeManager.shared.$currentMode
            .sink { [weak self] _ in
                self?.lastSuggestionTimes.removeAll()
            }
            .store(in: &cancellables)
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier
        else { return }

        if let mode = appModeRules[bundleID] {
            if mode != ModeManager.shared.currentMode {
                // If this suggestion is already active, don't trigger it again
                if suggestedMode == mode {
                    return
                }

                // Cooldown: 60 seconds per bundle ID
                let now = Date()
                if let lastTime = lastSuggestionTimes[bundleID], now.timeIntervalSince(lastTime) < 60 {
                    return
                }

                lastSuggestionTimes[bundleID] = now
                suggestedMode = mode
            } else {
                suggestedMode = nil
            }
        } else {
            suggestedMode = nil
        }
    }

    func dismiss() {
        suggestedMode = nil
    }

    func apply() {
        guard let mode = suggestedMode else { return }
        ModeManager.shared.currentMode = mode
        suggestedMode = nil
    }
}
