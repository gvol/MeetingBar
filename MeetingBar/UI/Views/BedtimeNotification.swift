//
//  BedtimeNotification.swift
//  MeetingBar
//

import SwiftUI

struct BedtimeNotification: View {
    var window: NSWindow?

    @State private var currentTime = Date()
    // Fires every second so the pre-midnight rainbow cycling is visibly animated.
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Garish rainbow palette used to ramp up urgency before midnight.
    private static let rainbowColors: [Color] = [
        Color(red: 1.0, green: 0.0, blue: 0.0), // red
        Color(red: 1.0, green: 0.45, blue: 0.0), // orange
        Color(red: 1.0, green: 0.95, blue: 0.0), // yellow
        Color(red: 0.0, green: 1.0, blue: 0.0), // green
        Color(red: 0.0, green: 0.6, blue: 1.0), // blue
        Color(red: 0.4, green: 0.0, blue: 1.0), // indigo
        Color(red: 1.0, green: 0.0, blue: 1.0), // violet
    ]

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Go to Bed Sleepyhead, it's already \(formattedTime)")
                    .font(.system(size: 36, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Button(action: dismiss) {
                    Text("Not quite yet")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 30)
                }
            }
            .padding(40)
        }
        .colorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(clockTimer) { time in
            currentTime = time
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
    }

    // Before midnight: cycles through garish rainbow colors, speeding up the closer
    // it gets to midnight so it feels increasingly urgent. From midnight to 3 AM the
    // cycling stops and it settles into a slow shift from near-black toward dark red.
    private var backgroundColor: Color {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: currentTime)
        let minute = cal.component(.minute, from: currentTime)
        let second = cal.component(.second, from: currentTime)

        if hour == 22 || hour == 23 {
            let secondsSince2200 = Double(((hour - 22) * 60 + minute) * 60 + second)
            let elapsed = max(0, secondsSince2200 - 30 * 60) // starts counting at 10:30 PM
            let windowLength = 90.0 * 60.0 // 10:30 PM -> midnight
            let t = min(elapsed / windowLength, 1.0)
            let interval = 15.0 - t * 13.0 // slows from 15s/color down to 2s/color
            let index = Int(elapsed / interval) % Self.rainbowColors.count
            return Self.rainbowColors[index]
        }

        guard hour < 6 else {
            return Color(red: 0.08, green: 0.08, blue: 0.12)
        }

        let minutesSinceMidnight = Double(hour * 60 + minute)
        let t = min(minutesSinceMidnight / 180.0, 1.0) // 0 at midnight, 1.0 at 3 AM
        return Color(
            red: 0.08 + t * (0.28 - 0.08),
            green: 0.08 * (1.0 - t),
            blue: 0.12 * (1.0 - t)
        )
    }

    private func dismiss() {
        window?.close()
    }
}

#Preview {
    BedtimeNotification(window: nil)
}
