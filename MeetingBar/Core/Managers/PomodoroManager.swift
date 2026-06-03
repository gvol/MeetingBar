//
//  PomodoroManager.swift
//  MeetingBar
//

import AppKit
import Defaults
import Foundation

@MainActor
final class PomodoroManager {
    /// Set after StatusBarItemController is created. Gives access to events + AppDelegate (for windows).
    weak var statusBar: StatusBarItemController?

    private(set) var type: PomodoroType?
    private(set) var phase: PomodoroPhase = .work
    private var phaseEndDate: Date?
    /// True when a phase has ended and the blocking full-screen is waiting for the user.
    private var awaitingUserAction = false
    /// True when the current cycle's break is aligned to a meeting (stop after it).
    private var currentCycleIsTerminal = false

    private var timer: Timer?
    /// The full-screen window currently shown, if any.
    private weak var notificationWindow: NSWindow?

    var isActive: Bool { type != nil }

    func attach(statusBar: StatusBarItemController) {
        self.statusBar = statusBar
    }

    // MARK: - Public control --------------------------------------------------

    /// Start a session. No-op if the preset cannot fit before the next meeting.
    func start(_ type: PomodoroType) {
        let gap = gapToNextMeetingSeconds()
        let plan = planPomodoroCycle(type: type, gapSeconds: gap)
        switch plan {
        case .cannotFit:
            return
        case let .nominal(workSeconds):
            self.type = type
            beginWorkPhase(workSeconds: workSeconds, terminal: false)
        case let .terminal(workSeconds):
            self.type = type
            beginWorkPhase(workSeconds: workSeconds, terminal: true)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        type = nil
        phaseEndDate = nil
        awaitingUserAction = false
        currentCycleIsTerminal = false
        notificationWindow?.close()
        notificationWindow = nil
        refreshUI()
    }

    // MARK: - Menu / title state ---------------------------------------------

    func menuState() -> PomodoroMenuState {
        if isActive, let type = type {
            return PomodoroMenuState(
                isActive: true,
                statusLine: pomodoroStatusLine(type: type, phase: phase, secondsRemaining: secondsRemaining()),
                shallowEnabled: false,
                deepEnabled: false,
                shallowTooltip: nil,
                deepTooltip: nil
            )
        }
        let gap = gapToNextMeetingSeconds()
        let shallowOK = planPomodoroCycle(type: .shallow, gapSeconds: gap) != .cannotFit
        let deepOK = planPomodoroCycle(type: .deep, gapSeconds: gap) != .cannotFit
        let tip = tooSoonTooltip(gap: gap)
        return PomodoroMenuState(
            isActive: false,
            statusLine: nil,
            shallowEnabled: shallowOK,
            deepEnabled: deepOK,
            shallowTooltip: shallowOK ? nil : tip,
            deepTooltip: deepOK ? nil : tip
        )
    }

    /// Menu-bar title while active, or nil when idle (caller falls back to normal title).
    func menuBarTitle() -> String? {
        guard isActive, let type = type else { return nil }
        return pomodoroMenuBarTitle(type: type, phase: phase, secondsRemaining: secondsRemaining())
    }

    // MARK: - Full-screen callbacks ------------------------------------------

    /// User clicked "Start break" / "Start work".
    func advancePhase() {
        notificationWindow?.close()
        notificationWindow = nil
        awaitingUserAction = false
        guard let type = type else { return }
        switch phase {
        case .work:
            beginBreakPhase(terminal: currentCycleIsTerminal)
        case .breakTime:
            // Replan the next cycle against the (possibly changed) next meeting.
            let plan = planPomodoroCycle(type: type, gapSeconds: gapToNextMeetingSeconds())
            switch plan {
            case .cannotFit:
                stop()
            case let .nominal(workSeconds):
                beginWorkPhase(workSeconds: workSeconds, terminal: false)
            case let .terminal(workSeconds):
                beginWorkPhase(workSeconds: workSeconds, terminal: true)
            }
        }
    }

    /// User clicked "Postpone 2 min": extend the current phase and re-arm.
    func postpone() {
        notificationWindow?.close()
        notificationWindow = nil
        awaitingUserAction = false
        let extra = Double(Defaults[.pomodoroPostponeMinutes] * 60)
        phaseEndDate = Date().addingTimeInterval(extra)
        startTimerIfNeeded()
        refreshUI()
    }

    // MARK: - Phase transitions ----------------------------------------------

    private func beginWorkPhase(workSeconds: Int, terminal: Bool) {
        phase = .work
        currentCycleIsTerminal = terminal
        phaseEndDate = Date().addingTimeInterval(Double(workSeconds))
        awaitingUserAction = false
        startTimerIfNeeded()
        refreshUI()
    }

    private func beginBreakPhase(terminal: Bool) {
        guard let type = type else { return }
        phase = .breakTime
        currentCycleIsTerminal = terminal
        phaseEndDate = Date().addingTimeInterval(Double(type.breakSeconds))
        awaitingUserAction = false
        startTimerIfNeeded()
        refreshUI()
    }

    private func handlePhaseEnd() {
        awaitingUserAction = true
        timer?.invalidate()
        timer = nil
        refreshUI()
        guard let app = statusBar?.appdelegate, let type = type else { return }

        switch phase {
        case .work:
            app.openPomodoroNotificationWindow(
                manager: self,
                title: "pomodoro_fs_break_title".loco(),
                subtitle: type.localizedName,
                advanceLabel: "pomodoro_fs_start_break".loco(),
                showPostpone: true,
                isTerminal: false
            )
        case .breakTime:
            if currentCycleIsTerminal {
                app.openPomodoroNotificationWindow(
                    manager: self,
                    title: "pomodoro_fs_complete_title".loco(),
                    subtitle: "",
                    advanceLabel: nil,        // terminal: single Close button
                    showPostpone: false,
                    isTerminal: true
                )
            } else {
                app.openPomodoroNotificationWindow(
                    manager: self,
                    title: "pomodoro_fs_work_title".loco(),
                    subtitle: type.localizedName,
                    advanceLabel: "pomodoro_fs_start_work".loco(),
                    showPostpone: true,
                    isTerminal: false
                )
            }
        }
    }

    /// Called by AppDelegate after creating the window so the manager can close it later.
    func registerNotificationWindow(_ window: NSWindow) {
        notificationWindow = window
    }

    /// Terminal "Close" button: just stop.
    func dismissTerminal() {
        stop()
    }

    // MARK: - Timer -----------------------------------------------------------

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        t.tolerance = 0.2
        RunLoop.current.add(t, forMode: .common)
        timer = t
    }

    @objc private func tick() {
        guard isActive, !awaitingUserAction, let end = phaseEndDate else { return }
        if Date() >= end {
            handlePhaseEnd()
        } else {
            statusBar?.updateTitle()
        }
    }

    // MARK: - Helpers ---------------------------------------------------------

    private func secondsRemaining() -> Int {
        guard let end = phaseEndDate else { return 0 }
        return Int(end.timeIntervalSinceNow.rounded(.up))
    }

    /// Gap (seconds) to the next meeting that starts in the future, or nil.
    private func gapToNextMeetingSeconds() -> Double? {
        guard let next = statusBar?.events.nextEvent() else { return nil }
        let gap = next.startDate.timeIntervalSinceNow
        return gap > 0 ? gap : nil
    }

    private func tooSoonTooltip(gap: Double?) -> String {
        let minutes = gap.map { max(0, Int($0 / 60)) } ?? 0
        return "pomodoro_menu_too_soon_tooltip".loco(String(minutes))
    }

    private func refreshUI() {
        statusBar?.updateTitle()
        statusBar?.updateMenu()
    }
}
