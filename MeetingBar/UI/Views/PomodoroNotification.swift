//
//  PomodoroNotification.swift
//  MeetingBar
//

import SwiftUI

struct PomodoroNotification: View {
    let title: String
    let subtitle: String
    /// nil => terminal screen with a single Close button.
    let advanceLabel: String?
    let showPostpone: Bool
    let isTerminal: Bool

    weak var manager: PomodoroManager?
    var window: NSWindow?

    var body: some View {
        ZStack {
            Rectangle.semiOpaqueWindow()
            VStack(spacing: 20) {
                Text(title).font(.largeTitle)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.title3).foregroundColor(.secondary)
                }
                HStack(spacing: 30) {
                    if isTerminal {
                        Button(action: closeTerminal) {
                            Text("general_close".loco()).padding(.vertical, 5).padding(.horizontal, 20)
                        }
                    } else {
                        if let advanceLabel = advanceLabel {
                            Button(action: advance) {
                                Text(advanceLabel).padding(.vertical, 5).padding(.horizontal, 25)
                            }.background(Color.accentColor).cornerRadius(5)
                        }
                        if showPostpone {
                            Button(action: postpone) {
                                Text("pomodoro_fs_postpone".loco()).padding(.vertical, 5).padding(.horizontal, 20)
                            }
                        }
                        Button(action: stop) {
                            Text("pomodoro_fs_stop".loco()).padding(.vertical, 5).padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .colorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func advance() {
        manager?.advancePhase()   // manager closes the window
    }

    private func postpone() {
        manager?.postpone()       // manager closes the window
    }

    private func stop() {
        manager?.stop()           // manager closes the window
    }

    private func closeTerminal() {
        manager?.dismissTerminal()
    }
}
