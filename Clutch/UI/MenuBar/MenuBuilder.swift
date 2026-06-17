import AppKit

enum MenuBuilder {

    static func build() -> NSMenu {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "clutch is watching", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        if let suggestion = ModeSuggester.shared.suggestedMode {
            let suggestItem = NSMenuItem(
                title: "💡 switch to \(suggestion.displayName)",
                action: #selector(AppDelegate.applySuggestion),
                keyEquivalent: ""
            )
            suggestItem.target = NSApp.delegate
            menu.addItem(suggestItem)
            menu.addItem(.separator())
        }

        let stats = AppState.shared.monthSummary
        let statsItem = NSMenuItem(
            title: "\(stats.totalSaves) saves this month",
            action: #selector(AppDelegate.openStats),
            keyEquivalent: ""
        )
        statsItem.target = NSApp.delegate
        menu.addItem(statsItem)

        menu.addItem(.separator())

        let modeMenu = NSMenu()
        for mode in Mode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(AppDelegate.switchMode(_:)),
                keyEquivalent: ""
            )
            item.representedObject = mode
            item.target = NSApp.delegate
            if mode == ModeManager.shared.currentMode {
                item.state = .on
            }
            modeMenu.addItem(item)
        }
        let modeItem = NSMenuItem(title: "mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())

        let wrappedItem = NSMenuItem(title: "monthly wrapped", action: #selector(AppDelegate.openWrapped), keyEquivalent: "")
        wrappedItem.target = NSApp.delegate
        menu.addItem(wrappedItem)

        let settingsItem = NSMenuItem(title: "settings", action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "quit clutch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}
