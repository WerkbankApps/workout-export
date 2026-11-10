import Foundation

/// Root object of the exported JSON file.
struct WorkoutExport: Codable {
    let exportedAt: Date
    let timeZone: String
    let filter: String
    let notes: [String]
    let context: AthleteContext
    let workouts: [WorkoutRecord]
}

/// Latest general fitness values that help to interpret the workouts.
struct AthleteContext: Codable {
    let restingHeartRateBpm: Double?
    let vo2MaxMlPerKgMin: Double?
}

/// A single workout with its summary statistics.
struct WorkoutRecord: Codable, Identifiable {
    let id: String
    let activityType: String
    let start: Date
    let end: Date
    let durationMinutes: Double
    let source: String?
    let indoor: Bool?
    let elevationAscendedMeters: Double?
    let temperatureCelsius: Double?
    let humidityPercent: Double?
    let effortScore: Double?
    let estimatedEffortScore: Double?
    let metrics: [String: MetricSummary]
    /// Only present for multi-part workouts (e.g. triathlon or intervals).
    let activities: [ActivityRecord]?
    /// Average heart rate per minute since workout start; index = minute, null = no data.
    let heartRatePerMinute: [Int?]?
}

/// A sub-activity of a workout.
struct ActivityRecord: Codable {
    let activityType: String
    let start: Date
    let end: Date?
    let durationMinutes: Double
    let metrics: [String: MetricSummary]
}

/// Aggregated values of one quantity type. Cumulative types use `total`, discrete types use average/min/max.
struct MetricSummary: Codable {
    let unit: String
    var total: Double?
    var average: Double?
    var minimum: Double?
    var maximum: Double?
}

extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
