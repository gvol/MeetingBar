//
//  BedtimeReminderManager.swift
//  MeetingBar
//

import AppKit
import Defaults
import Foundation

@MainActor
final class BedtimeReminderManager {
    weak var statusBar: StatusBarItemController?

    private var timer: Timer?
    private var lastFiredAt: Date?
    private weak var notificationWindow: NSWindow?

    func attach(statusBar: StatusBarItemController) {
        self.statusBar = statusBar
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndFire()
            }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func registerNotificationWindow(_ window: NSWindow) {
        notificationWindow = window
    }

    // True during 10:30 PM – 5:59 AM when the feature is enabled
    var isInBedtimeWindow: Bool {
        guard Defaults[.bedtimeRemindersEnabled] else { return false }
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        return (hour == 22 && minute >= 30) || hour == 23 || hour < 6
    }

    // MARK: - Private

    private func checkAndFire() {
        guard Defaults[.bedtimeRemindersEnabled] else { return }

        let now = Date()
        let slots = tonightSchedule()
        guard !slots.isEmpty else { return }

        let unfired = slots.filter { slot in
            slot <= now && (lastFiredAt == nil || slot > lastFiredAt!)
        }

        guard let slotToFire = unfired.last else { return }

        lastFiredAt = slotToFire
        notificationWindow?.close()
        statusBar?.openBedtimeNotification()
        statusBar?.updateMenu()
    }

    private func tonightSchedule() -> [Date] {
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)

        guard (hour == 22 && minute >= 30) || hour == 23 || hour < 6 else {
            return []
        }

        let eveningBase: Date
        let cutoff: Date

        if hour < 6 {
            // Overnight: base is yesterday 10:30 PM, cutoff is today 6:00 AM
            let yesterday = cal.date(byAdding: .day, value: -1, to: startOfDay)!
            eveningBase = cal.date(bySettingHour: 22, minute: 30, second: 0, of: yesterday)!
            cutoff = cal.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay)!
        } else {
            // Evening: base is today 10:30 PM, cutoff is tomorrow 6:00 AM
            eveningBase = cal.date(bySettingHour: 22, minute: 30, second: 0, of: startOfDay)!
            let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfDay)!
            cutoff = cal.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow)!
        }

        var slots: [Date] = []

        // 4 × 15 min: 10:30, 10:45, 11:00, 11:15 PM
        // 6 × 5 min:  11:20, 11:25, 11:30, 11:35, 11:40, 11:45 PM
        let fixedOffsets: [TimeInterval] = [
            0, 15 * 60, 30 * 60, 45 * 60,
            50 * 60, 55 * 60, 60 * 60, 65 * 60, 70 * 60, 75 * 60,
        ]
        for offset in fixedOffsets {
            let slot = eveningBase.addingTimeInterval(offset)
            if slot < cutoff { slots.append(slot) }
        }

        // Every minute 11:46 PM (76 min) through 5:59 AM (449 min)
        for minute in 76 ... 449 {
            let slot = eveningBase.addingTimeInterval(TimeInterval(minute * 60))
            if slot < cutoff { slots.append(slot) }
        }

        return slots
    }
}
