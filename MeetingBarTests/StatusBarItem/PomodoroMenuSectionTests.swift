//
//  PomodoroMenuSectionTests.swift
//  MeetingBar
//

import XCTest
@testable import MeetingBar

@MainActor
final class PomodoroMenuSectionTests: BaseTestCase {
    private class Dummy: NSObject {}

    func test_idle_showsBothStartItems() {
        let state = PomodoroMenuState(
            isActive: false, statusLine: nil,
            shallowEnabled: true, deepEnabled: true,
            shallowTooltip: nil, deepTooltip: nil
        )
        let items = MenuBuilder(target: Dummy()).buildPomodoroSection(state: state)
        let titles = MenuBuilder.plainTitles(of: items)
        XCTAssertTrue(titles.contains("pomodoro_menu_start_shallow".loco()))
        XCTAssertTrue(titles.contains("pomodoro_menu_start_deep".loco()))
        XCTAssertFalse(titles.contains("pomodoro_menu_stop".loco()))
        XCTAssertTrue(items.allSatisfy { $0.isEnabled })
    }

    func test_idle_disablesDeepWithTooltip_whenDeepCannotFit() {
        let state = PomodoroMenuState(
            isActive: false, statusLine: nil,
            shallowEnabled: true, deepEnabled: false,
            shallowTooltip: nil, deepTooltip: "Meeting in 18 min — too soon to start"
        )
        let items = MenuBuilder(target: Dummy()).buildPomodoroSection(state: state)
        let deep = items.first { $0.title == "pomodoro_menu_start_deep".loco() }!
        XCTAssertFalse(deep.isEnabled)
        XCTAssertEqual(deep.toolTip, "Meeting in 18 min — too soon to start")
        let shallow = items.first { $0.title == "pomodoro_menu_start_shallow".loco() }!
        XCTAssertTrue(shallow.isEnabled)
    }

    func test_active_showsStatusRowAndStop_hidesStartItems() {
        let state = PomodoroMenuState(
            isActive: true, statusLine: "🧠 Deep work — 12:30 left",
            shallowEnabled: false, deepEnabled: false,
            shallowTooltip: nil, deepTooltip: nil
        )
        let items = MenuBuilder(target: Dummy()).buildPomodoroSection(state: state)
        let titles = MenuBuilder.plainTitles(of: items)
        XCTAssertEqual(titles.first, "🧠 Deep work — 12:30 left")
        XCTAssertFalse(items[0].isEnabled)   // status row disabled
        XCTAssertTrue(titles.contains("pomodoro_menu_stop".loco()))
        XCTAssertFalse(titles.contains("pomodoro_menu_start_shallow".loco()))
        XCTAssertFalse(titles.contains("pomodoro_menu_start_deep".loco()))
        let stop = items.first { $0.title == "pomodoro_menu_stop".loco() }!
        XCTAssertEqual(stop.action, #selector(StatusBarItemController.stopPomodoro))
    }
}
