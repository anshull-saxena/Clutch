import AppKit
import Combine

final class StatusBarController: NSObject, NSMenuDelegate {

    static let shared = StatusBarController()
    private var statusItem: NSStatusItem!
    private var flashTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = Self.menuBarIcon
            button.toolTip = "Clutch — i got u"
        }

        let menu = MenuBuilder.build()
        menu.delegate = self
        statusItem.menu = menu

        AppState.shared.$monthSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                self?.updateStatsMenuTitle(summary.totalSaves)
            }
            .store(in: &cancellables)

        ModeManager.shared.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateModeCheckmarks()
            }
            .store(in: &cancellables)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuItems(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusItem.menu = MenuBuilder.build()
        statusItem.menu?.delegate = self
        updateMenuItems(statusItem.menu!)
    }

    private func updateMenuItems(_ menu: NSMenu) {
        updateStatsMenuTitle(AppState.shared.monthSummary.totalSaves)
        updateModeCheckmarks()
    }

    private func updateStatsMenuTitle(_ totalSaves: Int) {
        guard let menu = statusItem.menu else { return }
        if let statsItem = menu.items.first(where: { $0.action == #selector(AppDelegate.openStats) }) {
            statsItem.title = "\(totalSaves) saves this month"
        }
    }

    private func updateModeCheckmarks() {
        guard let menu = statusItem.menu else { return }
        if let modeItem = menu.items.first(where: { $0.submenu != nil && $0.title == "mode" }),
           let submenu = modeItem.submenu {
            let currentMode = ModeManager.shared.currentMode
            for item in submenu.items {
                if let mode = item.representedObject as? Mode {
                    item.state = (mode == currentMode) ? .on : .off
                }
            }
        }
    }

    func flashSaved() {
        flashTimer?.invalidate()
        statusItem.button?.image = NSImage(
            systemSymbolName: "checkmark.shield.fill",
            accessibilityDescription: "saved"
        )
        flashTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.resetIcon()
        }
    }

    func resetIcon() {
        flashTimer?.invalidate()
        flashTimer = nil
        statusItem.button?.image = Self.menuBarIcon
    }

    private static var menuBarIcon: NSImage? {
        let icon = Bundle.module.image(forResource: "menubar")
            ?? NSImage(named: "menubar")
        icon?.isTemplate = true
        return icon
    }
}
