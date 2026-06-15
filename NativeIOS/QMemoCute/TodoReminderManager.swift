import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct TodoAlarmMetadata: AlarmMetadata {
    let memoID: UUID
    let todoItemID: UUID
}
#endif

final class TodoReminderManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TodoReminderManager()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "qmemo.todo."

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) == true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func requestUrgentAuthorizationIfNeeded() async -> Bool {
        guard #available(iOS 26.0, *) else {
            return await requestAuthorizationIfNeeded()
        }

        #if canImport(AlarmKit)
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            return (try? await manager.requestAuthorization()) == .authorized
        case .denied:
            return false
        @unknown default:
            return false
        }
        #else
        return await requestAuthorizationIfNeeded()
        #endif
    }

    func synchronize(memoID: UUID, title: String, items: [MemoTodoItem]) async {
        let prefix = reminderIdentifierPrefix(for: memoID)
        let pendingRequests = await center.pendingNotificationRequests()
        let existingIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

        if #available(iOS 26.0, *) {
            cancelSystemAlarms(for: items)
        }

        let scheduledItems = items.filter { item in
            guard
                !item.isCompleted,
                let reminderAt = item.reminderAt,
                reminderAt > Date()
            else {
                return false
            }

            return !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !scheduledItems.isEmpty else { return }

        for item in scheduledItems {
            guard let reminderAt = item.reminderAt else { continue }

            if item.isUrgent, #available(iOS 26.0, *) {
                if await scheduleSystemAlarm(
                    memoID: memoID,
                    item: item,
                    reminderAt: reminderAt
                ) {
                    continue
                }
            }

            guard await requestAuthorizationIfNeeded() else { continue }
            scheduleNotification(
                memoID: memoID,
                title: title,
                item: item,
                reminderAt: reminderAt
            )
        }
    }

    func cancelReminders(memoID: UUID, items: [MemoTodoItem]) async {
        let prefix = reminderIdentifierPrefix(for: memoID)
        let pendingRequests = await center.pendingNotificationRequests()
        let identifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        if #available(iOS 26.0, *) {
            cancelSystemAlarms(for: items)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    private func scheduleNotification(
        memoID: UUID,
        title: String,
        item: MemoTodoItem,
        reminderAt: Date
    ) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = item.text
            content.sound = .default
            content.userInfo = [
                "memoID": memoID.uuidString,
                "todoItemID": item.id.uuidString
            ]

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderAt
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(memoID: memoID, itemID: item.id),
                content: content,
                trigger: trigger
            )
            center.add(request)
    }

    @available(iOS 26.0, *)
    private func scheduleSystemAlarm(
        memoID: UUID,
        item: MemoTodoItem,
        reminderAt: Date
    ) async -> Bool {
        #if canImport(AlarmKit)
        guard await requestUrgentAuthorizationIfNeeded() else { return false }

        let alarmTitle = LocalizedStringResource(stringLiteral: item.text)
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: alarmTitle)
        } else {
            alert = AlarmPresentation.Alert(
                title: alarmTitle,
                stopButton: AlarmButton(
                    text: "停止",
                    textColor: .white,
                    systemImageName: "stop.fill"
                )
            )
        }
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: TodoAlarmMetadata(memoID: memoID, todoItemID: item.id),
            tintColor: .pink
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(reminderAt),
            attributes: attributes
        )

        do {
            try? AlarmManager.shared.cancel(id: item.id)
            _ = try await AlarmManager.shared.schedule(
                id: item.id,
                configuration: configuration
            )
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    @available(iOS 26.0, *)
    private func cancelSystemAlarms(for items: [MemoTodoItem]) {
        #if canImport(AlarmKit)
        for item in items {
            try? AlarmManager.shared.cancel(id: item.id)
        }
        #endif
    }

    private func reminderIdentifierPrefix(for memoID: UUID) -> String {
        "\(identifierPrefix)\(memoID.uuidString)."
    }

    private func reminderIdentifier(memoID: UUID, itemID: UUID) -> String {
        "\(reminderIdentifierPrefix(for: memoID))\(itemID.uuidString)"
    }
}
