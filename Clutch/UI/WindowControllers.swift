import AppKit
import SwiftUI

// MARK: - Stats

final class StatsWindowController: NSWindowController {
    static let shared = StatsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: StatsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clutch Stats"
        window.contentViewController = hosting
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Wrapped

final class WrappedWindowController: NSWindowController {
    static let shared = WrappedWindowController()

    private init() {
        let hosting = NSHostingController(rootView: WrappedContainerView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clutch Wrapped"
        window.contentViewController = hosting
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        AppState.shared.loadWrappedStats()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Onboarding

final class OnboardingWindowController: NSWindowController {
    private static var activeController: OnboardingWindowController?

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: UDKeys.hasOnboarded) else { return }
        show()
    }

    static func show() {
        let controller = OnboardingWindowController()
        activeController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private init() {
        let hosting = NSHostingController(
            rootView: OnboardingView(onComplete: { OnboardingWindowController.activeController?.finish() })
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Clutch"
        window.contentViewController = hosting
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func finish() {
        window?.close()
        Self.activeController = nil
    }
}
