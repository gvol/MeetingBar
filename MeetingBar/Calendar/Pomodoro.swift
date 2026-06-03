//
//  Pomodoro.swift
//  MeetingBar
//

import Defaults
import Foundation

/// Which Pomodoro preset the user started.
enum PomodoroType {
    case shallow
    case deep

    /// Nominal work length in seconds (read from Defaults so it is future-tunable).
    var workNominalSeconds: Int {
        switch self {
        case .shallow: return Defaults[.pomodoroShallowWorkMinutes] * 60
        case .deep: return Defaults[.pomodoroDeepWorkMinutes] * 60
        }
    }

    /// Break length in seconds.
    var breakSeconds: Int {
        switch self {
        case .shallow: return Defaults[.pomodoroShallowBreakMinutes] * 60
        case .deep: return Defaults[.pomodoroDeepBreakMinutes] * 60
        }
    }

    /// Emoji shown while working.
    var workIcon: String {
        switch self {
        case .shallow: return "🍅"
        case .deep: return "🧠"
        }
    }

    /// Localized human name ("Shallow work" / "Deep work").
    var localizedName: String {
        switch self {
        case .shallow: return "pomodoro_shallow_work".loco()
        case .deep: return "pomodoro_deep_work".loco()
        }
    }
}

/// Icon shown during a break (same for both presets).
let pomodoroBreakIcon = "☕"

enum PomodoroPhase {
    case work
    case breakTime
}

/// Outcome of planning one cycle against the gap to the next meeting.
enum PomodoroPlan: Equatable {
    /// Run a full nominal cycle, then replan the next one.
    case nominal(workSeconds: Int)
    /// Run work+break, then stop (break ends exactly at meeting start).
    case terminal(workSeconds: Int)
    /// Not enough time before the meeting to start a sensible session.
    case cannotFit
}

/// Pure planning logic. `gapSeconds` is the time until the next meeting starts,
/// or nil if there is no upcoming meeting to align to.
func planPomodoroCycle(
    workNominalSeconds: Int,
    breakSeconds: Int,
    floorSeconds: Int,
    gapSeconds: Double?
) -> PomodoroPlan {
    guard let gap = gapSeconds else {
        return .nominal(workSeconds: workNominalSeconds)
    }
    let nominalCycle = Double(workNominalSeconds + breakSeconds)
    let snapThreshold = nominalCycle + Double(floorSeconds + breakSeconds)
    if gap >= snapThreshold {
        return .nominal(workSeconds: workNominalSeconds)
    }
    let work = Int(gap) - breakSeconds
    if work >= floorSeconds {
        return .terminal(workSeconds: work)
    }
    return .cannotFit
}

/// Convenience wrapper that reads the preset + floor from Defaults.
func planPomodoroCycle(type: PomodoroType, gapSeconds: Double?) -> PomodoroPlan {
    planPomodoroCycle(
        workNominalSeconds: type.workNominalSeconds,
        breakSeconds: type.breakSeconds,
        floorSeconds: Defaults[.pomodoroFloorMinutes] * 60,
        gapSeconds: gapSeconds
    )
}

/// "MM:SS" from a (possibly negative) seconds-remaining value. Negative clamps to 0.
func pomodoroClock(secondsRemaining: Int) -> String {
    let s = max(0, secondsRemaining)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

/// Menu-bar title while a session runs, e.g. "🍅 24:59" or "☕ 04:59".
func pomodoroMenuBarTitle(type: PomodoroType, phase: PomodoroPhase, secondsRemaining: Int) -> String {
    let icon = phase == .work ? type.workIcon : pomodoroBreakIcon
    return "\(icon) \(pomodoroClock(secondsRemaining: secondsRemaining))"
}

/// Disabled status row in the dropdown, e.g. "🧠 Deep work — 12:30 left".
func pomodoroStatusLine(type: PomodoroType, phase: PomodoroPhase, secondsRemaining: Int) -> String {
    let icon = phase == .work ? type.workIcon : pomodoroBreakIcon
    let name = phase == .work ? type.localizedName : "pomodoro_break".loco()
    let clock = pomodoroClock(secondsRemaining: secondsRemaining)
    return "\(icon) " + "pomodoro_menu_status".loco(name, clock)
}

/// Everything `MenuBuilder` needs to render the Pomodoro section, computed by the manager.
struct PomodoroMenuState {
    var isActive: Bool
    var statusLine: String?      // present when isActive
    var shallowEnabled: Bool
    var deepEnabled: Bool
    var shallowTooltip: String?  // present when !shallowEnabled
    var deepTooltip: String?     // present when !deepEnabled
}
