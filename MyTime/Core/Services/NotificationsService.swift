//
//  NotificationsService.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import Foundation
import UserNotifications

class NotificationsService {
    static let shared = NotificationsService()
    private var center = UNUserNotificationCenter.current()

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

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger,

        )

        do {
            try await center.add(request)
        } catch {
            print(error)
        }
    }

    func removePending() {
        center.removeAllPendingNotificationRequests()
    }

    func removeDelivered() {
        center.removeAllDeliveredNotifications()
    }

    func removeAll() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
