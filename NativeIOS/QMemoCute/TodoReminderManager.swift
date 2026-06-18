import Foundation
import OSLog
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

struct TodoReminderSyncReport {
    var scheduledSystemAlarmIDs: Set<UUID> = []
    var failedSystemAlarms: [UUID: String] = [:]

    func systemAlarmWasScheduled(for itemID: UUID) -> Bool {
        scheduledSystemAlarmIDs.contains(itemID)
    }
}

private enum TodoSystemAlarmError: LocalizedError {
    case authorizationDenied
    case registrationMissing
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "系统闹钟权限未开启"
        case .registrationMissing:
            return "系统没有保留刚创建的闹钟"
        case .schedulingFailed(let message):
            return "系统闹钟创建失败：\(message)"
        }
    }
}

final class TodoReminderManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TodoReminderManager()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "qmemo.todo."
    private let logger = Logger(subsystem: "com.memorybunny.qmemo", category: "TodoReminder")

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

    @discardableResult
    func synchronize(
        memoID: UUID,
        title: String,
        items: [MemoTodoItem]
    ) async -> TodoReminderSyncReport {
        var report = TodoReminderSyncReport()
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
        guard !scheduledItems.isEmpty else { return report }

        for item in scheduledItems {
            guard let reminderAt = item.reminderAt else { continue }

            if item.isUrgent, #available(iOS 26.0, *) {
                let result = await scheduleSystemAlarm(
                    memoID: memoID,
                    item: item,
                    reminderAt: reminderAt
                )
                switch result {
                case .success:
                    report.scheduledSystemAlarmIDs.insert(item.id)
                    continue
                case .failure(let error):
                    let message = error.localizedDescription
                    report.failedSystemAlarms[item.id] = message
                    logger.error("AlarmKit scheduling failed for item \(item.id, privacy: .public): \(message, privacy: .public)")
                }
            }

            guard await requestAuthorizationIfNeeded() else { continue }
            await scheduleNotification(
                memoID: memoID,
                title: title,
                item: item,
                reminderAt: reminderAt
            )
        }

        return report
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
    ) async {
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

        do {
            try await center.add(request)
        } catch {
            logger.error("Notification fallback failed for item \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    @available(iOS 26.0, *)
    private func scheduleSystemAlarm(
        memoID: UUID,
        item: MemoTodoItem,
        reminderAt: Date
    ) async -> Result<Void, TodoSystemAlarmError> {
        #if canImport(AlarmKit)
        guard await requestUrgentAuthorizationIfNeeded() else {
            return .failure(.authorizationDenied)
        }

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
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: .fixed(reminderAt),
            attributes: attributes,
            sound: .default
        )

        do {
            let manager = AlarmManager.shared
            try? manager.cancel(id: item.id)
            let alarm = try await manager.schedule(
                id: item.id,
                configuration: configuration
            )
            guard alarm.id == item.id else {
                return .failure(.registrationMissing)
            }

            if try manager.alarms.contains(where: { $0.id == item.id }) {
                return .success(())
            }

            try await Task.sleep(for: .milliseconds(150))
            guard try manager.alarms.contains(where: { $0.id == item.id }) else {
                return .failure(.registrationMissing)
            }
            return .success(())
        } catch {
            return .failure(.schedulingFailed(error.localizedDescription))
        }
        #else
        return .failure(.schedulingFailed("当前系统不支持 AlarmKit"))
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
