# Clutch — macOS Menu Bar App
### Build specification · v1.0

> **One-line brief:** A macOS menu bar app that instantly mutes your speakers the moment your headphones unplug — and does it with the personality of a friend who has your back at 3AM.

---

## Table of contents

1. [Product concept](#1-product-concept)
2. [Tech stack & requirements](#2-tech-stack--requirements)
3. [Project structure](#3-project-structure)
4. [Core engine — audio device monitoring](#4-core-engine--audio-device-monitoring)
5. [Mute / unmute logic](#5-mute--unmute-logic)
6. [Menu bar UI](#6-menu-bar-ui)
7. [Settings window](#7-settings-window)
8. [Event log & persistence](#8-event-log--persistence)
9. [Notification system](#9-notification-system)
10. [Modes system](#10-modes-system)
11. [Gamification — badges & stats](#11-gamification--badges--stats)
12. [Monthly wrapped](#12-monthly-wrapped)
13. [Onboarding flow](#13-onboarding-flow)
14. [Build, signing & distribution](#14-build-signing--distribution)
15. [Copy & tone guide](#15-copy--tone-guide)

---

## 1. Product concept

### The problem
Every macOS user has experienced the same jumpscare: headphones yank out mid-session and the laptop's speakers immediately broadcast whatever was playing — lo-fi at 2AM, an embarrassing Spotify playlist in the library, audio during a Discord call. macOS has no native protection for this.

### The solution
Clutch is a background menu bar daemon (~50KB binary) that listens for CoreAudio device-change events. The instant a headphone/earphone device disconnects, it mutes system audio in under 40ms. When headphones reconnect, it restores audio. It logs every save, gamifies your close calls, and talks to you like a friend instead of a system alert.

### Personality
- **Name:** Clutch
- **Tagline:** Your bestie in the menu bar.
- **Voice:** lowercase, direct, a little chaotic, dark-humored. Never clinical.
- **Target user:** Gen Z macOS users in dorms, libraries, hostels, open-plan spaces.

---

## 2. Tech stack & requirements

### Language & frameworks
- **Swift 5.9+** — entire codebase
- **AppKit** — `NSStatusItem`, `NSMenu`, `NSPanel` for menu bar presence
- **SwiftUI** — Settings window, stats panel, onboarding, wrapped screen
- **CoreAudio** — device change listeners, mute control
- **IOKit** — USB transport type detection (distinguish headphones from other audio devices)
- **UserNotifications** — notification delivery
- **SQLite (via GRDB or raw)** — event log persistence
- **Combine** — reactive state propagation between engine and UI

### System requirements
- macOS 13 Ventura minimum (for SwiftUI compatibility + newer CoreAudio APIs)
- No network access required — fully local, privacy-first
- No microphone/camera permission required
- Accessibility permission NOT required (CoreAudio route change is system-level)

### Xcode project settings
```
Product Name: Clutch
Bundle Identifier: com.yourname.clutch
Deployment Target: macOS 13.0
Signing: Personal Team (free) or Apple Developer ($99/yr for notarization)
App Sandbox: OFF (required for CoreAudio global device access)
Hardened Runtime: ON (required for notarization)
Background Modes: Audio (tick "Audio, AirPlay, and Picture in Picture" in capabilities)
LSUIElement: YES  ← in Info.plist — hides the Dock icon, menu bar only
```

### Info.plist additions
```xml
<key>LSUIElement</key>
<true/>
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 3. Project structure

```
Clutch/
├── App/
│   ├── CclutchApp.swift          ← @main, sets up AppDelegate
│   └── AppDelegate.swift         ← NSApplicationDelegate, wires everything
│
├── Engine/
│   ├── AudioDeviceMonitor.swift  ← CoreAudio listener, detects unplug events
│   ├── AudioController.swift     ← mute/unmute, volume read/write
│   └── DeviceClassifier.swift    ← distinguishes headphones from speakers/USB audio
│
├── Models/
│   ├── ClutchEvent.swift         ← single save event (timestamp, volume, app, risk)
│   ├── Badge.swift               ← badge definition + earned state
│   ├── Mode.swift                ← enum of app modes
│   └── WrappedStats.swift        ← monthly stats aggregate
│
├── Storage/
│   ├── EventStore.swift          ← SQLite CRUD for ClutchEvent
│   └── Migrations.swift          ← DB schema versioning
│
├── Notifications/
│   ├── NotificationManager.swift ← UNUserNotificationCenter wrapper
│   └── NotificationCopy.swift    ← all notification strings by scenario
│
├── UI/
│   ├── MenuBar/
│   │   ├── StatusBarController.swift   ← NSStatusItem setup
│   │   └── MenuBuilder.swift           ← builds NSMenu programmatically
│   ├── Settings/
│   │   ├── SettingsWindow.swift        ← SwiftUI Settings host
│   │   ├── GeneralTab.swift
│   │   ├── ModesTab.swift
│   │   └── NotificationsTab.swift
│   ├── Stats/
│   │   ├── StatsView.swift             ← close call log + badges
│   │   └── BadgeGridView.swift
│   ├── Wrapped/
│   │   └── WrappedView.swift           ← shareable monthly summary
│   └── Onboarding/
│       └── OnboardingView.swift
│
├── Resources/
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   └── MenuBarIcon.imageset/       ← template image, 18x18 @2x
│   └── Sounds/
│       └── clutch_save.aiff            ← optional subtle confirmation sound
│
└── Support/
    ├── Constants.swift
    ├── Extensions.swift
    └── UserDefaultsKeys.swift
```

---

## 4. Core engine — audio device monitoring

This is the heart of the app. We register a CoreAudio property listener on the system's hardware device list. When any device change fires, we inspect what changed and whether it was a headphone disconnect.

### `AudioDeviceMonitor.swift`

```swift
import CoreAudio
import Combine

final class AudioDeviceMonitor: ObservableObject {

    static let shared = AudioDeviceMonitor()

    // Publisher that fires with the disconnected device info
    let headphonesDisconnected = PassthroughSubject<AudioDeviceInfo, Never>()
    let headphonesConnected    = PassthroughSubject<AudioDeviceInfo, Never>()

    private var knownDevices: Set<AudioDeviceID> = []
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    private init() {}

    func startMonitoring() {
        // Snapshot current devices
        knownDevices = Set(getAllOutputDeviceIDs())

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        listenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleDeviceListChange()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInteractive),
            listenerBlock!
        )
    }

    func stopMonitoring() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInteractive),
            block
        )
    }

    private func handleDeviceListChange() {
        let current = Set(getAllOutputDeviceIDs())
        let removed = knownDevices.subtracting(current)
        let added   = current.subtracting(knownDevices)

        for deviceID in removed {
            // Device was present, now gone — check if it was headphones
            // We must check against our cached info since the device is gone
            if let info = cachedDeviceInfo[deviceID],
               DeviceClassifier.isHeadphoneDevice(info) {
                headphonesDisconnected.send(info)
            }
        }

        for deviceID in added {
            if let info = getDeviceInfo(deviceID),
               DeviceClassifier.isHeadphoneDevice(info) {
                headphonesConnected.send(info)
            }
        }

        // Update snapshot and cache
        knownDevices = current
        refreshDeviceCache()
    }

    // MARK: - CoreAudio helpers

    private func getAllOutputDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        return deviceIDs.filter { hasOutputStream($0) }
    }

    private func hasOutputStream(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return err == noErr && dataSize > 0
    }
}
```

### `DeviceClassifier.swift`

```swift
import CoreAudio
import IOKit

struct AudioDeviceInfo {
    let deviceID: AudioDeviceID
    let name: String
    let transportType: UInt32
    let uid: String
}

enum DeviceClassifier {

    /// Returns true if the device is a headphone/earphone (wired or wireless)
    static func isHeadphoneDevice(_ info: AudioDeviceInfo) -> Bool {
        let headphoneTransports: Set<UInt32> = [
            kAudioDeviceTransportTypeUSB,       // USB DAC / USB-C headphones
            kAudioDeviceTransportTypeBluetooth, // AirPods, BT headphones
            kAudioDeviceTransportTypeBluetoothLE,
            kAudioDeviceTransportTypeBuiltIn,   // 3.5mm on older Macs (with port)
            kAudioDeviceTransportTypeThunderbolt
        ]

        // Exclude virtual/aggregate devices
        if info.transportType == kAudioDeviceTransportTypeVirtual { return false }
        if info.transportType == kAudioDeviceTransportTypeAggregate { return false }

        // Built-in speakers are NOT headphones; built-in headphone jack IS
        if info.transportType == kAudioDeviceTransportTypeBuiltIn {
            return info.name.lowercased().contains("headphone") ||
                   info.uid.lowercased().contains("headphone")
        }

        return headphoneTransports.contains(info.transportType)
    }
}
```

---

## 5. Mute / unmute logic

### `AudioController.swift`

```swift
import CoreAudio

final class AudioController {

    static let shared = AudioController()
    private init() {}

    // Volume snapshot before muting (so we can restore it exactly)
    private var prePlugVolume: Float = 0.5
    private var wasMuted: Bool = false

    // MARK: - Public interface

    func muteOnUnplug() {
        let defaultDevice = getDefaultOutputDevice()
        prePlugVolume = getVolume(for: defaultDevice)
        wasMuted = getMuted(for: defaultDevice)

        guard !wasMuted else { return } // already muted, do nothing

        setMuted(true, for: defaultDevice)

        // Belt-and-suspenders: also zero the volume
        // (some apps bypass the mute flag)
        setVolume(0.0, for: defaultDevice)
    }

    func restoreOnPlug() {
        guard !wasMuted else { return } // was already muted before, leave it

        let defaultDevice = getDefaultOutputDevice()
        setMuted(false, for: defaultDevice)
        setVolume(prePlugVolume, for: defaultDevice)
    }

    func currentVolume() -> Float {
        return getVolume(for: getDefaultOutputDevice())
    }

    // MARK: - CoreAudio primitives

    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    private func getVolume(for deviceID: AudioDeviceID) -> Float {
        var volume: Float32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        return volume
    }

    private func setVolume(_ volume: Float, for deviceID: AudioDeviceID) {
        var vol = Float32(volume)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &vol
        )
    }

    private func getMuted(for deviceID: AudioDeviceID) -> Bool {
        var muted: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &muted)
        return muted != 0
    }

    private func setMuted(_ muted: Bool, for deviceID: AudioDeviceID) {
        var val = UInt32(muted ? 1 : 0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &val
        )
    }
}
```

### Wiring it up in `AppDelegate.swift`

```swift
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    private var cancellables = Set<AnyCancellable>()
    private let monitor = AudioDeviceMonitor.shared
    private let audio   = AudioController.shared

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
    }

    private func handleUnplug(_ device: AudioDeviceInfo) {
        let volumeBefore = audio.currentVolume()
        audio.muteOnUnplug()

        // Build event
        let event = ClutchEvent(
            timestamp:    Date(),
            deviceName:   device.name,
            volumeAtSave: volumeBefore,
            frontmostApp: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
            mode:         ModeManager.shared.currentMode,
            riskScore:    RiskCalculator.score(volume: volumeBefore, hour: Calendar.current.component(.hour, from: Date()))
        )

        EventStore.shared.save(event)
        BadgeEngine.shared.evaluate(event)
        NotificationManager.shared.sendSaveNotification(for: event)
        StatusBarController.shared.flashSaved()
    }

    private func handlePlug(_ device: AudioDeviceInfo) {
        audio.restoreOnPlug()
        StatusBarController.shared.resetIcon()
    }
}
```

---

## 6. Menu bar UI

### `StatusBarController.swift`

```swift
import AppKit

final class StatusBarController {

    static let shared = StatusBarController()
    private var statusItem: NSStatusItem!
    private var flashTimer: Timer?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")  // template image, white/black auto
            button.image?.isTemplate = true
            button.toolTip = "Clutch — i got u"
        }

        statusItem.menu = MenuBuilder.build()
    }

    func flashSaved() {
        // Briefly show a checkmark icon to signal a save occurred
        flashTimer?.invalidate()
        statusItem.button?.image = NSImage(systemSymbolName: "checkmark.shield.fill",
                                           accessibilityDescription: "saved")
        flashTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.resetIcon()
        }
    }

    func resetIcon() {
        statusItem.button?.image = NSImage(named: "MenuBarIcon")
        statusItem.button?.image?.isTemplate = true
    }
}
```

### `MenuBuilder.swift`

```swift
import AppKit

enum MenuBuilder {

    static func build() -> NSMenu {
        let menu = NSMenu()

        // Header — current status
        let statusItem = NSMenuItem(title: "clutch is watching", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Stats summary
        let stats = EventStore.shared.thisMonthSummary()
        let statsItem = NSMenuItem(
            title: "\(stats.totalSaves) saves this month",
            action: #selector(AppDelegate.openStats),
            keyEquivalent: ""
        )
        statsItem.target = NSApp.delegate
        menu.addItem(statsItem)

        menu.addItem(.separator())

        // Mode switcher
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

        // Wrapped
        let wrappedItem = NSMenuItem(title: "monthly wrapped", action: #selector(AppDelegate.openWrapped), keyEquivalent: "")
        wrappedItem.target = NSApp.delegate
        menu.addItem(wrappedItem)

        // Settings
        let settingsItem = NSMenuItem(title: "settings", action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "quit clutch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}
```

---

## 7. Settings window

Built in SwiftUI. Opened via `NSWindow` hosting a `SwiftUI` view. Three tabs: General, Modes, Notifications.

### `SettingsWindow.swift`

```swift
import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let view = SettingsView()
        let hosting = NSHostingController(rootView: view)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clutch settings"
        window.contentViewController = hosting
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("general", systemImage: "gearshape") }
            ModesTab()
                .tabItem { Label("modes", systemImage: "moon.stars") }
            NotificationsTab()
                .tabItem { Label("notifications", systemImage: "bell") }
        }
        .padding(20)
        .frame(width: 480, height: 420)
    }
}
```

### `GeneralTab.swift`

```swift
import SwiftUI

struct GeneralTab: View {
    @AppStorage(UDKeys.launchAtLogin)     var launchAtLogin     = true
    @AppStorage(UDKeys.playSaveSound)     var playSaveSound     = false
    @AppStorage(UDKeys.autoRestoreAudio)  var autoRestoreAudio  = true
    @AppStorage(UDKeys.showRiskScore)     var showRiskScore     = true

    var body: some View {
        Form {
            Section {
                Toggle("launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in LaunchManager.toggle(launchAtLogin) }

                Toggle("auto-restore audio when headphones reconnect", isOn: $autoRestoreAudio)

                Toggle("play subtle save sound on mute", isOn: $playSaveSound)

                Toggle("show risk score in close call log", isOn: $showRiskScore)
            }
        }
        .formStyle(.grouped)
    }
}
```

### `ModesTab.swift`

```swift
import SwiftUI

struct ModesTab: View {
    @StateObject private var modeManager = ModeManager.shared

    var body: some View {
        List {
            ForEach(Mode.allCases) { mode in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: mode.iconName)
                        .font(.title2)
                        .frame(width: 28)
                        .foregroundStyle(mode == modeManager.currentMode ? .purple : .secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mode.displayName)
                            .font(.headline)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if mode == modeManager.currentMode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.purple)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { modeManager.currentMode = mode }
                .padding(.vertical, 4)
            }
        }
    }
}
```

---

## 8. Event log & persistence

### `ClutchEvent.swift`

```swift
import Foundation

struct ClutchEvent: Identifiable, Codable {
    let id:           UUID
    let timestamp:    Date
    let deviceName:   String
    let volumeAtSave: Float       // 0.0 – 1.0
    let frontmostApp: String      // "Spotify", "Discord", etc.
    let mode:         Mode
    let riskScore:    Int         // 0–100

    var riskLabel: String {
        switch riskScore {
        case 80...100: return "crisis"
        case 50...79:  return "awkward"
        default:       return "mild"
        }
    }

    var volumePercent: Int {
        Int(volumeAtSave * 100)
    }
}
```

### `RiskCalculator.swift`

```swift
enum RiskCalculator {

    /// Computes a 0–100 cringe score based on context
    static func score(volume: Float, hour: Int) -> Int {
        var score = Int(volume * 60)  // volume contributes up to 60 pts

        // Late night multiplier
        let lateNight = (hour >= 23 || hour <= 4)
        if lateNight { score += 25 }

        // Morning silence window
        let earlyMorning = (hour >= 5 && hour <= 7)
        if earlyMorning { score += 15 }

        return min(score, 100)
    }
}
```

### `EventStore.swift`

```swift
import Foundation
import GRDB   // Add via Swift Package Manager: https://github.com/groue/GRDB.swift

final class EventStore {

    static let shared = EventStore()
    private var dbQueue: DatabaseQueue!

    private init() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clutch/events.db")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbQueue = try? DatabaseQueue(path: url.path)
        try? dbQueue.write { db in
            try db.create(table: "clutch_events", ifNotExists: true) { t in
                t.column("id",           .text).primaryKey()
                t.column("timestamp",    .datetime).notNull()
                t.column("device_name",  .text).notNull()
                t.column("volume",       .double).notNull()
                t.column("app_name",     .text).notNull()
                t.column("mode",         .text).notNull()
                t.column("risk_score",   .integer).notNull()
            }
        }
    }

    func save(_ event: ClutchEvent) {
        try? dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO clutch_events (id, timestamp, device_name, volume, app_name, mode, risk_score)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id.uuidString,
                    event.timestamp,
                    event.deviceName,
                    event.volumeAtSave,
                    event.frontmostApp,
                    event.mode.rawValue,
                    event.riskScore
                ]
            )
        }
    }

    func recent(limit: Int = 50) -> [ClutchEvent] {
        // fetch and map rows to ClutchEvent
        // implementation left as standard GRDB fetch pattern
        return []
    }

    func thisMonthSummary() -> MonthSummary {
        // aggregate query: count, max risk, 3AM saves, streak
        return MonthSummary(totalSaves: 0, highestRisk: 0, lateNightSaves: 0, streakDays: 0)
    }

    func clearAll() {
        try? dbQueue.write { db in
            try db.execute(sql: "DELETE FROM clutch_events")
        }
    }
}

struct MonthSummary {
    let totalSaves:    Int
    let highestRisk:   Int
    let lateNightSaves: Int
    let streakDays:    Int
}
```

---

## 9. Notification system

### `NotificationCopy.swift`

All notification strings. Always lowercase. Never more than 2 sentences. Reference context when possible.

```swift
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
```

### `NotificationManager.swift`

```swift
import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendSaveNotification(for event: ClutchEvent) {
        // Stealth mode: silent
        if ModeManager.shared.currentMode == .stealth { return }

        let copy  = NotificationCopy.saveMessage(for: event)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body  = copy.body

        // No sound for late-night saves (mode = threeAM)
        if ModeManager.shared.currentMode != .threeAM {
            content.sound = .none  // quiet by default, no notification sound
        }

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

---

## 10. Modes system

### `Mode.swift`

```swift
import Foundation

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
```

### `ModeManager.swift`

```swift
import Foundation
import Combine

final class ModeManager: ObservableObject {

    static let shared = ModeManager()

    @Published var currentMode: Mode = .normal {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: UDKeys.currentMode)
        }
    }

    private var autoTimer: Timer?

    private init() {
        let saved = UserDefaults.standard.string(forKey: UDKeys.currentMode) ?? "normal"
        currentMode = Mode(rawValue: saved) ?? .normal
        startAutoModeCheck()
    }

    // Auto-switch to 3AM mode between midnight and 5AM
    private func startAutoModeCheck() {
        autoTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            let hour = Calendar.current.component(.hour, from: Date())
            let isLateNight = hour >= 23 || hour < 5

            if isLateNight && self?.currentMode == .normal {
                self?.currentMode = .threeAM
            } else if !isLateNight && self?.currentMode == .threeAM {
                self?.currentMode = .normal
            }
        }
    }
}
```

---

## 11. Gamification — badges & stats

### Badge definitions

```swift
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
```

### `BadgeEngine.swift`

```swift
import Foundation

final class BadgeEngine {

    static let shared = BadgeEngine()
    private init() {}

    private let earnedKey = "earned_badge_ids"

    var earnedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: earnedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: earnedKey) }
    }

    /// Called after every save event. Evaluates all unearned badges.
    func evaluate(_ event: ClutchEvent) {
        let store = EventStore.shared
        var newlyEarned: [Badge] = []

        let total      = store.recent(limit: 10000).count
        let lateNight  = store.recent(limit: 10000).filter {
            let h = Calendar.current.component(.hour, from: $0.timestamp)
            return h >= 0 && h < 5
        }.count
        let streak     = store.thisMonthSummary().streakDays

        let checks: [(String, Bool)] = [
            ("first_save",     total >= 1),
            ("crisis_averted", event.riskScore >= 90),
            ("three_am",       lateNight >= 5),
            ("library",        event.mode == .library),
            ("discord",        event.frontmostApp.lowercased().contains("discord")),
            ("family_safe",    streak >= 7),
            ("hundred",        total >= 100),
            ("unbothered",     streak >= 30),
            ("goblin",         event.mode == .goblin),
            ("night_owl",      lateNight >= 10),
        ]

        for (id, condition) in checks {
            if condition && !earnedIDs.contains(id) {
                earnedIDs.insert(id)
                if let badge = Badge.all.first(where: { $0.id == id }) {
                    newlyEarned.append(badge)
                }
            }
        }

        // Notify about newly earned badges
        for badge in newlyEarned {
            NotificationManager.shared.sendBadgeNotification(badge)
        }
    }
}
```

---

## 12. Monthly wrapped

### `WrappedStats.swift`

```swift
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
```

### `WrappedView.swift`

```swift
import SwiftUI

struct WrappedView: View {

    let stats: WrappedStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text(stats.month)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Text(stats.headline)
                .font(.title2)
                .fontWeight(.medium)
                .padding(.bottom, 24)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WrappedStatCard(label: "crises averted", value: "\(stats.totalSaves)")
                WrappedStatCard(label: "highest risk save", value: "\(stats.highestRiskSave?.volumePercent ?? 0)%")
                WrappedStatCard(label: "saves after midnight", value: "\(stats.lateNightSaves)")
                WrappedStatCard(label: "clean day streak", value: "\(stats.bestStreak) days")
            }
            .padding(.bottom, 20)

            // Most saved from
            if !stats.mostSavedFrom.isEmpty {
                Text("most saves while in \(stats.mostSavedFrom)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }

            // Share button
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(stats.shareText, forType: .string)
            } label: {
                Label("copy to share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(width: 380)
    }
}

struct WrappedStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

---

## 13. Onboarding flow

### `OnboardingView.swift`

Single-screen onboarding shown on first launch. No carousel. One screen, straight to the point.

```swift
import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) var dismiss
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

            // Icon placeholder
            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
                .padding(.bottom, 20)

            Text("clutch has your back.")
                .font(.title)
                .fontWeight(.medium)
                .padding(.bottom, 8)

            Text("the second your headphones unplug, i mute your speakers.\nno jumpscare. no embarrassment. just handled.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // Notification permission
            VStack(spacing: 8) {
                Button {
                    NotificationManager.shared.requestPermission()
                    permissionGranted = true
                } label: {
                    Text(permissionGranted ? "notifications on — nice" : "allow notifications")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.horizontal, 40)

                Text("i'll let you know when i save you. lowercase only. no drama.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 20)

            Button("let's go") {
                UserDefaults.standard.set(true, forKey: UDKeys.hasOnboarded)
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(width: 440, height: 380)
    }
}
```

---

## 14. Build, signing & distribution

### Launch at login
Use `ServiceManagement` framework (macOS 13+):

```swift
import ServiceManagement

enum LaunchManager {
    static func toggle(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLogin error: \(error)")
        }
    }
}
```

### Notarization checklist
1. Enable Hardened Runtime in Xcode → Signing & Capabilities
2. Disable App Sandbox (required for CoreAudio global device access — note this in privacy policy)
3. Archive → Distribute App → Notarize
4. Staple: `xcrun stapler staple Clutch.app`
5. Wrap: `create-dmg Clutch.app ./dist/`

### UserDefaults keys

```swift
enum UDKeys {
    static let hasOnboarded    = "has_onboarded"
    static let currentMode     = "current_mode"
    static let launchAtLogin   = "launch_at_login"
    static let playSaveSound   = "play_save_sound"
    static let autoRestoreAudio = "auto_restore_audio"
    static let showRiskScore   = "show_risk_score"
    static let earnedBadgeIDs  = "earned_badge_ids"
}
```

### Third-party dependencies (Swift Package Manager)
Add in Xcode → File → Add Package Dependencies:

| Package | URL | Purpose |
|---|---|---|
| GRDB | `https://github.com/groue/GRDB.swift` | SQLite event store |
| LaunchAtLogin (optional) | `https://github.com/sindresorhus/LaunchAtLogin-Modern` | Simpler launch-at-login |

### App size target
- Binary: < 2MB
- SQLite DB grows ~1KB per 100 events — negligible
- No network calls, no telemetry, ever

---

## 15. Copy & tone guide

### Rules
- Always lowercase — everywhere, including button labels, menu items, notification titles
- Never more than 2 sentences in a notification
- Never use: "error", "muted", "audio device", "configuration", "system", "event detected"
- Use instead: "got you", "handled", "close call", "saved", "bestie", "fr", "on me"
- Reference context when possible: app name, time, volume %, mode
- Occasionally nudge: "drink water", "go to sleep", but sparingly (max once per 5 saves)

### Tone ladder by risk score

| Risk | Tone | Example notification |
|---|---|---|
| 0–30 | calm, unbothered | "handled. carry on." |
| 31–60 | friendly | "close call. ur villain arc playlist stays classified." |
| 61–80 | protective | "caught in 4k? not today. \(app) at \(vol)%." |
| 81–100 | chaotic | "\(vol)%. bestie. i am the reason you still have friends." |

### Menu bar text
- While idle: `clutch is watching`
- After save: `clutch saved u — just now`
- Mode active: `clutch · 3am mode`

### Onboarding copy rules
No bullet points. No feature lists. Feels like a text from a friend, not an app tutorial.

---

*end of spec — go build it*
