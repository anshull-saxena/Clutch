import AVFoundation
import UserNotifications

enum PermissionManager {
    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    static func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static func requestNotifications(completion: ((Bool) -> Void)? = nil) {
        NotificationManager.shared.requestPermission(completion: completion)
    }

    static func notificationsAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        NotificationManager.shared.getAuthorizationStatus(completion: completion)
    }
}
