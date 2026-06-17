import SwiftUI

struct ModesTab: View {
    @ObservedObject private var modeManager = ModeManager.shared

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
