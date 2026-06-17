import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var cancellables = Set<AnyCancellable>()
    private let monitor = AudioDeviceMonitor.shared
    private let audio   = AudioController.shared
    private let workQueue = DispatchQueue(label: "com.clutch.save", qos: .userInitiated)

    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarController.shared.setup()
        monitor.startMonitoring()

        monitor.headphonesDisconnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceInfo in
                self?.handleUnplug(deviceInfo)
            }
            .store(in: &cancellables)

        monitor.headphonesConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceInfo in
                self?.handlePlug(deviceInfo)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .clutchEventSaved)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                AppState.shared.handleEventSaved()
            }
            .store(in: &cancellables)

        AppState.shared.refreshMonthSummary()
        OnboardingWindowController.showIfNeeded()

        _ = NotificationManager.shared
        NotificationManager.shared.getAuthorizationStatus { status in
            if status == .notDetermined {
                NotificationManager.shared.requestPermission()
            }
        }

        _ = ModeSuggester.shared

        ModeSuggester.shared.$suggestedMode
            .receive(on: DispatchQueue.main)
            .sink { mode in
                if let mode = mode {
                    SuggestionWindowController.shared.show(for: mode)
                } else {
                    SuggestionWindowController.shared.close()
                }
            }
            .store(in: &cancellables)
    }

    private func handleUnplug(_ device: AudioDeviceInfo) {
        let currentMode = ModeManager.shared.currentMode

        if currentMode == .stealth {
            audio.muteOnUnplug()
            return
        }

        let isCallAppRunning = ModeSuggester.shared.suggestedMode == .callMode
        if currentMode == .callMode || isCallAppRunning {
            audio.muteInput()
        }

        let volumeBefore = audio.currentVolume()
        audio.muteOnUnplug()
        StatusBarController.shared.flashSaved()

        let event = ClutchEvent(
            id: UUID(),
            timestamp:    Date(),
            deviceName:   device.name,
            volumeAtSave: volumeBefore,
            frontmostApp: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
            mode:         currentMode,
            riskScore:    RiskCalculator.score(
                volume: volumeBefore,
                hour: Calendar.current.component(.hour, from: Date())
            )
        )

        let playSound = UserDefaults.standard.bool(forKey: UDKeys.playSaveSound)

        workQueue.async {
            EventStore.shared.save(event)
            let newBadges = BadgeEngine.shared.evaluate(event)

            DispatchQueue.main.async {
                NotificationManager.shared.sendSaveNotification(for: event)
                for badge in newBadges {
                    NotificationManager.shared.sendBadgeNotification(badge)
                }

                if playSound,
                   let soundURL = Bundle.main.url(forResource: "clutch_save", withExtension: "aiff"),
                   let sound = NSSound(contentsOf: soundURL, byReference: true) {
                    sound.play()
                }
            }
        }
    }

    private func handlePlug(_ device: AudioDeviceInfo) {
        audio.restoreOnPlug()
        StatusBarController.shared.resetIcon()
    }

    @objc func openStats() {
        StatsWindowController.shared.show()
        AppState.shared.loadRecentEvents()
    }

    @objc func openSettings() {
        SettingsWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openWrapped() {
        WrappedWindowController.shared.show()
    }

    @objc func switchMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? Mode else { return }
        ModeManager.shared.currentMode = mode
        ModeSuggester.shared.dismiss()

        if mode == .goblin {
            ModeManager.shared.checkGoblinWeeklyRecap(forceCheck: true)
        }
    }

    @objc func applySuggestion() {
        ModeSuggester.shared.apply()
    }
}
