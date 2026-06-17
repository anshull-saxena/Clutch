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

            Section {
                Button("re-run setup") {
                    OnboardingWindowController.show()
                }
            }
        }
        .formStyle(.grouped)
    }
}
