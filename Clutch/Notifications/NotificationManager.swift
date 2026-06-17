import Foundation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.clutch.app", category: "notifications")

extension Notification.Name {
    static let notificationAuthStatusChanged = Notification.Name("NotificationAuthStatusChanged")
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        logger.info("Initializing NotificationManager and setting UNUserNotificationCenter delegate")
        UNUserNotificationCenter.current().delegate = self
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            logger.info("getAuthorizationStatus = \(settings.authorizationStatus.rawValue) (0:notDetermined, 1:denied, 2:authorized, 3:provisional, 4:ephemeral)")
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        logger.info("Requesting notification authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            logger.info("Authorization request finished. Granted: \(granted), Error: \(error?.localizedDescription ?? "None")")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationAuthStatusChanged, object: nil)
                completion?(granted)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info("userNotificationCenter willPresent notification: \(notification.request.identifier)")
        // Support both banner and alert/sound presentation options
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.info("userNotificationCenter didReceive response for identifier: \(response.notification.request.identifier)")
        completionHandler()
    }

    func sendSaveNotification(for event: ClutchEvent) {
        logger.info("sendSaveNotification called for event: \(event.id)")
        // Stealth mode: silent
        if ModeManager.shared.currentMode == .stealth {
            logger.info("sendSaveNotification skipped because mode is stealth")
            return
        }

        let copy  = NotificationCopy.saveMessage(for: event)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body  = copy.body

        // No sound for late-night saves (mode = threeAM)
        if ModeManager.shared.currentMode == .threeAM {
            content.sound = .none
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "rizz_sound_mono.aiff"))
        }

        let request = UNNotificationRequest(
            identifier: "com.clutch.save",
            content: content,
            trigger: nil  // deliver immediately
        )

        logger.info("Adding notification request \(request.identifier) to notification center...")
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                logger.info("Notification successfully added to UNUserNotificationCenter")
            }
        }
    }

    func sendBadgeNotification(_ badge: Badge) {
        logger.info("sendBadgeNotification called for badge: \(badge.name)")
        let content = UNMutableNotificationContent()
        content.title = "clutch badge earned"
        content.body  = "you unlocked the '\(badge.name)' badge. slay."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "rizz_sound_mono.aiff"))

        let request = UNNotificationRequest(
            identifier: "com.clutch.badge",
            content: content,
            trigger: nil
        )
        
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule badge notification: \(error.localizedDescription)")
            } else {
                logger.info("Badge notification successfully added")
            }
        }
    }

    func sendCustomNotification(title: String, body: String) {
        logger.info("sendCustomNotification called: \(title) - \(body)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "rizz_sound_mono.aiff"))

        let request = UNNotificationRequest(identifier: "com.clutch.test", content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule custom notification: \(error.localizedDescription)")
            } else {
                logger.info("Custom notification successfully added")
            }
        }
    }
}
