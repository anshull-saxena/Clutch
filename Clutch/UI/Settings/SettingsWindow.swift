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
