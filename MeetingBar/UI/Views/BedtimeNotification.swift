//
//  BedtimeNotification.swift
//  MeetingBar
//

import SwiftUI

struct BedtimeNotification: View {
    var window: NSWindow?

    @State private var currentTime = Date()
    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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

    // Dark near-black before midnight; shifts toward dark red from midnight to 3 AM
    private var backgroundColor: Color {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: currentTime)
        let minute = cal.component(.minute, from: currentTime)

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
