import UserNotifications
import SwiftData

class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(dueCardCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-review"])

        guard dueCardCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to review!"
        content.body = "You have \(dueCardCount) card\(dueCardCount == 1 ? "" : "s") due for review."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-review",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}
