#if DEBUG && targetEnvironment(simulator)
import Foundation
import HealthKit

/// Fills the Simulator's Health store with sample workouts, so the real HealthKit flow can be tested.
/// Development only: it needs write access, which the shipping app never asks for.
///
/// Started by the "Testdaten erzeugen / entfernen (Simulator)" buttons in the empty state.
/// `seed()` replaces earlier test data with fresh samples, `reset()` removes everything this app saved.
enum HealthSeeder {
    private static let store = HKHealthStore()

    private static let quantityTypes: [HKQuantityType] = [
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
    ]

    private static var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        quantityTypes.forEach { types.insert($0) }
        return types
    }

    /// One sample workout. Workouts with `withMetrics == false` have no samples at all.
    private struct Sample {
        let type: HKWorkoutActivityType
        let daysAgo: Int
        let hour: Int
        let minutes: Int
        let distanceMeters: Double?
        let averageHeartRate: Double
        let kilocalories: Double
        var withMetrics = true
    }

    private static let samples: [Sample] = [
        Sample(type: .running, daysAgo: 0, hour: 7, minutes: 48, distanceMeters: 8_420, averageHeartRate: 152, kilocalories: 612),
        Sample(type: .traditionalStrengthTraining, daysAgo: 1, hour: 18, minutes: 55, distanceMeters: nil, averageHeartRate: 118, kilocalories: 340),
        Sample(type: .cycling, daysAgo: 2, hour: 16, minutes: 92, distanceMeters: 38_600, averageHeartRate: 141, kilocalories: 905),
        Sample(type: .yoga, daysAgo: 3, hour: 20, minutes: 30, distanceMeters: nil, averageHeartRate: 0, kilocalories: 0, withMetrics: false),
        Sample(type: .highIntensityIntervalTraining, daysAgo: 4, hour: 6, minutes: 25, distanceMeters: nil, averageHeartRate: 163, kilocalories: 330),
        Sample(type: .swimming, daysAgo: 5, hour: 12, minutes: 40, distanceMeters: 1_500, averageHeartRate: 134, kilocalories: 420),
        Sample(type: .running, daysAgo: 6, hour: 8, minutes: 118, distanceMeters: 21_100, averageHeartRate: 158, kilocalories: 1_480),
        Sample(type: .hiking, daysAgo: 8, hour: 10, minutes: 210, distanceMeters: 12_300, averageHeartRate: 112, kilocalories: 980),
    ]

    // MARK: - Public

    /// Replaces earlier test data with fresh sample workouts and returns a report of what happened.
    static func seed() async -> String {
        var lines: [String] = []
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: shareTypes)
            lines.append("Zugriff: Anfrage abgeschlossen")
        } catch {
            return "Testdaten FEHLER bei der Freigabe: \(error.localizedDescription)"
        }

        do {
            let removed = try await removeOwnData()
            lines.append("Alte Testdaten entfernt: \(removed)")
        } catch {
            lines.append("Alte Testdaten entfernen FEHLER: \(error.localizedDescription)")
        }

        var saved = 0
        for sample in samples {
            do {
                try await save(sample)
                saved += 1
            } catch {
                lines.append("Speichern \(sample.type.rawValue) FEHLER: \(error.localizedDescription)")
            }
        }
        lines.insert("\(saved) von \(samples.count) Testworkouts gespeichert", at: 0)
        lines.append(await readBack())
        return lines.joined(separator: "\n")
    }

    /// Removes everything this app saved to Health and returns a report.
    static func reset() async -> String {
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: shareTypes)
            let removed = try await removeOwnData()
            return "Testdaten entfernt: \(removed) Einträge\n" + (await readBack())
        } catch {
            return "Testdaten entfernen FEHLER: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// Returns how many objects were deleted.
    private static func removeOwnData() async throws -> Int {
        let ownData = HKQuery.predicateForObjects(from: HKSource.default())
        var removed = 0
        for type in shareTypes {
            removed += try await store.deleteObjects(of: type, predicate: ownData)
        }
        return removed
    }

    /// Reads the workouts back, the same way the app does, to prove they are visible.
    private static func readBack() async -> String {
        do {
            let descriptor = HKSampleQueryDescriptor(predicates: [.workout()], sortDescriptors: [], limit: nil)
            let workouts = try await descriptor.result(for: store)
            return "Aus Health lesbar: \(workouts.count) Workouts"
        } catch {
            return "Aus Health lesen FEHLER: \(error.localizedDescription)"
        }
    }

    private static func save(_ sample: Sample) async throws {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -sample.daysAgo, to: calendar.startOfDay(for: .now)) ?? .now
        let start = calendar.date(bySettingHour: sample.hour, minute: 0, second: 0, of: day) ?? day
        let end = start.addingTimeInterval(Double(sample.minutes) * 60)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = sample.type
        configuration.locationType = sample.distanceMeters == nil ? .indoor : .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
        try await builder.beginCollection(at: start)

        if sample.withMetrics {
            var samples: [HKSample] = heartRateSamples(for: sample, from: start)
            samples.append(HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: sample.kilocalories),
                start: start, end: end
            ))
            if let meters = sample.distanceMeters {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(distanceIdentifier(for: sample.type)),
                    quantity: HKQuantity(unit: .meter(), doubleValue: meters),
                    start: start, end: end
                ))
            }
            try await builder.addSamples(samples)
        }

        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    /// One heart rate sample per minute, varying smoothly around the average.
    private static func heartRateSamples(for sample: Sample, from start: Date) -> [HKSample] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        return (0..<sample.minutes).map { minute in
            let wave = sin(Double(minute) / 6) * 8
            let warmUp = minute < 5 ? -Double(5 - minute) * 6 : 0
            let bpm = max(55, sample.averageHeartRate + wave + warmUp)
            let from = start.addingTimeInterval(Double(minute) * 60)
            return HKQuantitySample(
                type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: unit, doubleValue: bpm.rounded()),
                start: from, end: from.addingTimeInterval(60)
            )
        }
    }

    private static func distanceIdentifier(for type: HKWorkoutActivityType) -> HKQuantityTypeIdentifier {
        switch type {
        case .cycling: .distanceCycling
        case .swimming: .distanceSwimming
        default: .distanceWalkingRunning
        }
    }
}
#endif
