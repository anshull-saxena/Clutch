import SwiftUI

enum Constants {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.unknown.clutch"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}
