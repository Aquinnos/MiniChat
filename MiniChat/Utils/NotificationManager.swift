//
//  NotificationManager.swift
//  MiniChat
//
//  Powiadomienia o zakończeniu odpowiedzi chatu + deep link do rozmowy.
//

import Foundation
import UserNotifications
import UIKit

extension Notification.Name {
    /// Broadcastowane gdy user tapnie w notyfikację - payload z conversationId.
    nonisolated static let openConversationRequested = Notification.Name("MiniChat.openConversationRequested")
}

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationGranted: Bool = false

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Pyta o zgodę na notyfikacje (raz). Bezpiecznie wywoływać wielokrotnie.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                authorizationGranted = granted
            } catch {
                Logger.log("Notification auth error: \(error)", category: "NotificationManager", level: .error)
                authorizationGranted = false
            }
        case .authorized, .provisional, .ephemeral:
            authorizationGranted = true
        case .denied:
            authorizationGranted = false
        @unknown default:
            authorizationGranted = false
        }
    }

    /// Wysyła natychmiastowe powiadomienie o zakończeniu odpowiedzi.
    /// Jeśli apka jest w foreground, delegate zwróci puste options (brak banner).
    func postResponseNotification(
        conversationId: UUID,
        conversationTitle: String,
        snippet: String
    ) {
        guard authorizationGranted else { return }

        let trimmedSnippet = snippet
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)

        let content = UNMutableNotificationContent()
        content.title = conversationTitle
        content.body = String(trimmedSnippet)
        content.sound = .default
        content.userInfo = [
            "conversationId": conversationId.uuidString,
            "type": "chat_response"
        ]
        content.categoryIdentifier = "CHAT_RESPONSE"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: conversationId),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Anuluje zarówno pending jak i delivered notyfikacje dla danej rozmowy.
    func clearNotification(conversationId: UUID) {
        let id = notificationIdentifier(for: conversationId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    private func notificationIdentifier(for conversationId: UUID) -> String {
        "chat_response_\(conversationId.uuidString)"
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Gdy apka jest w foreground - nie pokazuj banner (user widzi odpowiedź na ekranie)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    // User tapnął w notyfikację - broadcastuj do apki
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let convIdString = userInfo["conversationId"] as? String,
           let convId = UUID(uuidString: convIdString) {
            NotificationCenter.default.post(
                name: .openConversationRequested,
                object: nil,
                userInfo: ["conversationId": convId]
            )
        }
        completionHandler()
    }
}
