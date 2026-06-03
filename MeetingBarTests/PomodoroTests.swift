//
//  PomodoroTests.swift
//  MeetingBar
//

@testable import MeetingBar
import XCTest
import Defaults

/// Planning logic. Uses explicit seconds so it does not depend on Defaults.
final class PomodoroPlanTests: BaseTestCase {
    // shallow-like preset
    private let work = 25 * 60      // 1500
    private let brk = 5 * 60        // 300
    private let floor = 10 * 60     // 600
    // snapThreshold = 1500 + 300 + 600 + 300 = 2700

    func test_noMeeting_isNominal() {
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: nil)
        XCTAssertEqual(plan, .nominal(workSeconds: 1500))
    }

    func test_meetingFarAway_isNominal() {
        // gap exactly at snapThreshold -> nominal
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: 2700)
        XCTAssertEqual(plan, .nominal(workSeconds: 1500))
    }

    func test_meetingIn20min_shrinksToTerminal15() {
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: 20 * 60)
        XCTAssertEqual(plan, .terminal(workSeconds: 15 * 60))
    }

    func test_meetingIn35min_growsToTerminal30() {
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: 35 * 60)
        XCTAssertEqual(plan, .terminal(workSeconds: 30 * 60))
    }

    func test_meetingTooSoon_cannotFit() {
        // gap 12 min -> work 7 min < floor 10 -> cannotFit
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: 12 * 60)
        XCTAssertEqual(plan, .cannotFit)
    }

    func test_shallowBoundaryAt15min_isSmallestTerminal() {
        // gap 15 min -> work exactly floor (10 min) -> terminal
        let plan = planPomodoroCycle(workNominalSeconds: work, breakSeconds: brk, floorSeconds: floor, gapSeconds: 15 * 60)
        XCTAssertEqual(plan, .terminal(workSeconds: 10 * 60))
    }

    func test_deepPresetViaType_cannotFitUnder25min() {
        // Defaults are at their app defaults inside BaseTestCase (removed domain -> default values).
        let plan = planPomodoroCycle(type: .deep, gapSeconds: 24 * 60)
        XCTAssertEqual(plan, .cannotFit)
        let plan2 = planPomodoroCycle(type: .deep, gapSeconds: 25 * 60)
        XCTAssertEqual(plan2, .terminal(workSeconds: 10 * 60))
    }
}

final class PomodoroFormatTests: BaseTestCase {
    func test_clockFormatsMMSS() {
        XCTAssertEqual(pomodoroClock(secondsRemaining: 0), "00:00")
        XCTAssertEqual(pomodoroClock(secondsRemaining: 65), "01:05")
        XCTAssertEqual(pomodoroClock(secondsRemaining: 90 * 60), "90:00")
    }

    func test_clockClampsNegative() {
        XCTAssertEqual(pomodoroClock(secondsRemaining: -5), "00:00")
    }

    func test_menuBarTitleUsesWorkIconWhileWorking() {
        let title = pomodoroMenuBarTitle(type: .shallow, phase: .work, secondsRemaining: 1499)
        XCTAssertEqual(title, "🍅 24:59")
    }

    func test_menuBarTitleUsesCoffeeWhileBreak() {
        let title = pomodoroMenuBarTitle(type: .deep, phase: .breakTime, secondsRemaining: 240)
        XCTAssertEqual(title, "☕ 04:00")
    }

    func test_statusLineUsesLocalizedTemplate() {
        let line = pomodoroStatusLine(type: .deep, phase: .work, secondsRemaining: 12 * 60 + 30)
        XCTAssertEqual(line, "🧠 Deep work — 12:30 left")
    }

    func test_statusLineBreakUsesCoffee() {
        let line = pomodoroStatusLine(type: .shallow, phase: .breakTime, secondsRemaining: 4 * 60)
        XCTAssertEqual(line, "☕ Break — 04:00 left")
    }
}
