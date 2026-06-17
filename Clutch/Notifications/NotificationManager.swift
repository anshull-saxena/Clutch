import Foundation
import UserNotifications

extension Notification.Name {
    static let notificationAuthStatusChanged = Notification.Name("NotificationAuthStatusChanged")
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationAuthStatusChanged, object: nil)
                completion?(granted)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func sendSaveNotification(for event: ClutchEvent) {
        // Stealth mode: silent
        if ModeManager.shared.currentMode == .stealth { return }

        let copy  = NotificationCopy.saveMessage(for: event)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body  = copy.body

        // No sound for late-night saves (mode = threeAM)
        if ModeManager.shared.currentMode == .threeAM {
            content.sound = .none
        }

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("notification error: \(error.localizedDescription)") }
        }
    }

    func sendBadgeNotification(_ badge: Badge) {
        let content = UNMutableNotificationContent()
        content.title = "clutch badge earned"
        content.body  = "you unlocked the '\(badge.name)' badge. slay."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("notification error: \(error.localizedDescription)") }
        }
    }

    func sendCustomNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("notification error: \(error.localizedDescription)") }
        }
    }
}
