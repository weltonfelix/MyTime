//
//  NotificationsService.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation
import UserNotifications

@MainActor
class NotificationsService {
    static let shared = NotificationsService()
    private var center = UNUserNotificationCenter.current()
    private var pendingRequestID: String?

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [
                .alert, .badge, .sound,
            ])
        } catch {
            print(error)
        }
    }

    func sendNotification(title: String, body: String, in interval: TimeInterval)
        async
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let id = UUID().uuidString
        pendingRequestID = id
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger,

        )

        do {
            try await center.add(request)
            // A stopped session may finish scheduling after its replacement has started.
            if pendingRequestID != id {
                center.removePendingNotificationRequests(withIdentifiers: [id])
            }
        } catch {
            print(error)
        }
    }

    func removePending() {
        pendingRequestID = nil
        center.removeAllPendingNotificationRequests()
    }

    func removeDelivered() {
        center.removeAllDeliveredNotifications()
    }

    func removeAll() {
        pendingRequestID = nil
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
