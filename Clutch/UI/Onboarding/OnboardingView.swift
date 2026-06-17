import SwiftUI
import UserNotifications
import AVFoundation

struct OnboardingView: View {

    var onComplete: () -> Void
    @State private var step = 0
    @State private var notifGranted: Bool? = nil
    @State private var micGranted: Bool? = nil
    @State private var isRequesting = false
    @AppStorage(UDKeys.launchAtLogin) var launchAtLogin = true

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.purple : Color.gray.opacity(0.25))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: step)
                }
            }
            .padding(.top, 20)

            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: notificationsStep
                case 2: microphoneStep
                case 3: launchStep
                case 4: doneStep
                default: EmptyView()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer()

            // Navigation
            HStack {
                if step > 0 {
                    Button("back") {
                        withAnimation { step -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: nextAction) {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(nextButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(isRequesting)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
        .frame(width: 480, height: 420)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 64))
                .foregroundStyle(.purple)
                .padding(.bottom, 24)

            Text("Welcome to Clutch.")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The app that saves your dignity.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            Text("The exact second your headphones unplug or disconnect, Clutch instantly mutes your speakers.\n\nNo jumpscare. No embarrassment. Just handled.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
                .padding(.bottom, 12)

            Text("Stay in the Loop")
                .font(.title2)
                .fontWeight(.bold)

            Text("I'll send you a quick heads-up when I save you from a close call. Lowercase, no drama, straight to your notifications.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

            permissionButton(
                isGranted: notifGranted,
                action: {
                    isRequesting = true
                    PermissionManager.requestNotifications { granted in
                        notifGranted = granted
                        isRequesting = false
                    }
                },
                grantLabel: "allow notifications",
                grantedLabel: "notifications on"
            )

            if notifGranted == false {
                settingsHint("Enable in System Settings → Notifications → Clutch")
            }
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
                .padding(.bottom, 12)

            Text("Call Mode Protection")
                .font(.title2)
                .fontWeight(.bold)

            Text("When you're on a call and your headphones disconnect, Clutch can mute your mic too — so no one hears what you didn't mean to share.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

            permissionButton(
                isGranted: micGranted,
                action: {
                    isRequesting = true
                    PermissionManager.requestMicrophone { granted in
                        micGranted = granted
                        isRequesting = false
                    }
                },
                grantLabel: "allow microphone access",
                grantedLabel: "microphone access on"
            )

            if micGranted == false {
                settingsHint("Enable in System Settings → Privacy & Security → Microphone")
            }
        }
    }

    private var launchStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
                .padding(.bottom, 12)

            Text("Always On Duty")
                .font(.title2)
                .fontWeight(.bold)

            Text("To keep you protected every time you use your Mac, Clutch needs to start automatically when you log in.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            Toggle("launch at login (recommended)", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _ in LaunchManager.toggle(launchAtLogin) }
                .padding(.horizontal, 40)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .padding(.bottom, 16)

            Text("You're all set.")
                .font(.title)
                .fontWeight(.bold)

            Text("Clutch is now protecting you. Find the headphones icon up in your menu bar to change modes or check your stats.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Shared Components

    private func permissionButton(isGranted: Bool?, action: @escaping () -> Void, grantLabel: String, grantedLabel: String) -> some View {
        Group {
            if isGranted == true {
                Label(grantedLabel, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.vertical, 6)
            } else {
                Button(action: action) {
                    Text(grantLabel)
                        .frame(width: 220)
                }
                .buttonStyle(.borderedProminent)
                .tint(isGranted == false ? .gray : .purple)
            }
        }
    }

    private func settingsHint(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.forward.app")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    // MARK: - Navigation

    private var nextButtonTitle: String {
        switch step {
        case 0: return "get started"
        case 4: return "finish setup"
        default: return "next"
        }
    }

    private func nextAction() {
        withAnimation {
            if step < totalSteps - 1 {
                step += 1
            } else {
                UserDefaults.standard.set(true, forKey: UDKeys.hasOnboarded)
                onComplete()
            }
        }
    }
}
