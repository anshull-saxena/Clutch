import SwiftUI
import AppKit

struct SuggestionPopupView: View {
    let mode: Mode
    var onApply: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon with soft background glow
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: modeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("switch to \(mode.displayName)?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(modeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: 6) {
                Button(action: onApply) {
                    Text("switch")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 60)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)

                Button(action: onDismiss) {
                    Text("dismiss")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 320, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1.5)
        )
    }

    private var modeIcon: String {
        switch mode {
        case .normal: return "headphones"
        case .threeAM: return "moon.stars.fill"
        case .library: return "building.columns.fill"
        case .parentZone: return "house.fill"
        case .callMode: return "phone.fill"
        case .stealth: return "eye.slash.fill"
        case .goblin: return "flame.fill"
        }
    }

    private var modeDescription: String {
        switch mode {
        case .normal: return "mutes on unplug, sends notification."
        case .threeAM: return "judges you late-night. silent alerts."
        case .library: return "double-layer safety mute."
        case .parentZone: return "pre-emptive volume warnings."
        case .callMode: return "mutes microphone & system output."
        case .stealth: return "silent mute, no alert, no trace."
        case .goblin: return "tracks weekly close call chaos."
        }
    }
}

// MARK: - Window Controller

final class SuggestionWindowController: NSWindowController {
    static let shared = SuggestionWindowController()
    private var dismissTimer: Timer?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.hasShadow = true
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(for mode: Mode) {
        dismissTimer?.invalidate()

        let view = SuggestionPopupView(
            mode: mode,
            onApply: { [weak self] in
                ModeSuggester.shared.apply()
                self?.close()
            },
            onDismiss: { [weak self] in
                ModeSuggester.shared.dismiss()
                self?.close()
            }
        )

        let hosting = NSHostingController(rootView: view)
        window?.contentViewController = hosting

        // Position at bottom right corner of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340
            let y = screenFrame.minY + 20
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        showWindow(nil)
        window?.orderFrontRegardless()

        // Auto dismiss after 8 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            ModeSuggester.shared.dismiss()
            self?.close()
        }
    }
}
