import Foundation
import HealthKit

/// Lightweight summary of a workout for the selection list.
struct WorkoutListItem: Identifiable, Hashable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let start: Date
    let duration: TimeInterval
    let distanceText: String?
    let averageHeartRate: Int?
    let activeEnergy: Int?
    let source: String
}

#if DEBUG
extension WorkoutListItem {
    /// Realistic sample week for previews and App Store screenshots.
    static let samples: [WorkoutListItem] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        func item(_ type: HKWorkoutActivityType, _ start: Date, minutes: Double, distance: String?, heartRate: Int, energy: Int) -> WorkoutListItem {
            WorkoutListItem(
                id: UUID(), activityType: type, start: start, duration: minutes * 60,
                distanceText: distance, averageHeartRate: heartRate, activeEnergy: energy, source: "Apple Watch"
            )
        }

        return [
            item(.running, date(daysAgo: 0, hour: 7, minute: 32), minutes: 48, distance: "8,42 km", heartRate: 152, energy: 612),
            item(.traditionalStrengthTraining, date(daysAgo: 1, hour: 18, minute: 10), minutes: 55, distance: nil, heartRate: 118, energy: 340),
            item(.cycling, date(daysAgo: 2, hour: 16, minute: 45), minutes: 92, distance: "38,60 km", heartRate: 141, energy: 905),
            item(.yoga, date(daysAgo: 3, hour: 20, minute: 0), minutes: 30, distance: nil, heartRate: 94, energy: 110),
            item(.highIntensityIntervalTraining, date(daysAgo: 4, hour: 6, minute: 50), minutes: 25, distance: nil, heartRate: 163, energy: 330),
            item(.swimming, date(daysAgo: 5, hour: 12, minute: 15), minutes: 40, distance: "1.500 m", heartRate: 134, energy: 420),
            item(.running, date(daysAgo: 6, hour: 8, minute: 5), minutes: 118, distance: "21,10 km", heartRate: 158, energy: 1480),
            item(.hiking, date(daysAgo: 8, hour: 10, minute: 30), minutes: 210, distance: "12,30 km", heartRate: 112, energy: 980),
        ]
    }()
}
#endif
