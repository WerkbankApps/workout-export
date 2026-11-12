import Foundation
import HealthKit
import Testing
@testable import WBA___Workout_Export

/// Simulates what the app sees for the different Health permission choices. HealthKit never reveals a
/// denial to the app: denied access and "no data" both come back as an empty result.
@MainActor
struct HealthAccessScenarioTests {

    // MARK: - Helpers

    private func workout(daysAgo: Int, type: HKWorkoutActivityType = .running) -> LoadedWorkout {
        let start = Date.now.addingTimeInterval(-Double(daysAgo) * 86_400)
        let item = WorkoutListItem(
            id: UUID(), activityType: type, start: start, duration: 1_800,
            distanceText: nil, averageHeartRate: nil, activeEnergy: nil, source: "Test"
        )
        return LoadedWorkout(item: item, workout: nil)
    }

    private func exporter(
        available: Bool = true,
        workouts: [LoadedWorkout] = [],
        accessError: (any Error)? = nil
    ) -> WorkoutExporter {
        WorkoutExporter(access: HealthAccess(
            isAvailable: { available },
            requestAccess: { if let accessError { throw accessError } },
            fetchWorkouts: { count, _ in Array(workouts.prefix(count)) }
        ))
    }

    private func record(metrics: [String: MetricSummary]) -> WorkoutRecord {
        WorkoutRecord(
            id: UUID().uuidString, activityType: "running",
            start: .now, end: .now.addingTimeInterval(1_800), durationMinutes: 30, source: nil,
            indoor: nil, elevationAscendedMeters: nil, temperatureCelsius: nil, humidityPercent: nil,
            effortScore: nil, estimatedEffortScore: nil, metrics: metrics, activities: nil, heartRatePerMinute: nil
        )
    }

    // MARK: - Everything granted

    @Test func allGranted_listsWorkoutsAndPreselectsOnlyTheNewest() async {
        let sut = exporter(workouts: [workout(daysAgo: 0), workout(daysAgo: 1), workout(daysAgo: 2)])

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.count == 3)
        #expect(sut.selectedIDs == [sut.items[0].id])
        #expect(sut.errorMessage == nil)
        #expect(sut.hasLoaded)
        #expect(!sut.isLoading)
    }

    @Test func allGranted_respectsTheRequestedCount() async {
        let sut = exporter(workouts: (0..<8).map { workout(daysAgo: $0) })

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.count == 5)
    }

    // MARK: - Nothing granted (or only irrelevant types)

    @Test func nothingGranted_showsHintToGrantAccess() async {
        // Denied read access: HealthKit returns no workouts, without any error.
        let sut = exporter(workouts: [])

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.isEmpty)
        #expect(sut.selectedIDs.isEmpty)
        #expect(sut.errorMessage == HealthMessages.noWorkouts)
        #expect(sut.hasLoaded)
        #expect(!sut.isLoading)
    }

    @Test func onlyIrrelevantTypesGranted_behavesLikeNothingGranted() async {
        // E.g. only "Schritte" or "Gewicht" allowed, but not "Trainings": from the app's view the
        // workout query is empty, so the same guidance must appear.
        let sut = exporter(workouts: [])

        await sut.loadList(count: 20, filter: .running)

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == HealthMessages.noWorkouts)
    }

    @Test func noWorkoutsExist_showsTheSameHint() async {
        // Access granted, but the person has not recorded any workout (e.g. App Review device).
        let sut = exporter(workouts: [])

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == HealthMessages.noWorkouts)
    }

    @Test func hintMentionsWhereToChangeTheAccess() {
        let text = HealthMessages.noWorkouts

        #expect(text.contains("Einstellungen › Apps › Health › Datenzugriff & Geräte"))
        #expect(text.contains("Trainings"))
        #expect(text.contains("freigegeben") || text.contains("frei"))
    }

    @Test func emptyResultClearsOldList_andLaterReloadRecovers() async {
        var available: [LoadedWorkout] = [workout(daysAgo: 0)]
        let sut = WorkoutExporter(access: HealthAccess(
            isAvailable: { true },
            requestAccess: {},
            fetchWorkouts: { _, _ in available }
        ))

        await sut.loadList(count: 5, filter: .all)
        #expect(sut.items.count == 1)

        // The person revokes access in Health, then reloads.
        available = []
        await sut.loadList(count: 5, filter: .all)
        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == HealthMessages.noWorkouts)

        // The person grants access again and reloads: the hint disappears.
        available = [workout(daysAgo: 0)]
        await sut.loadList(count: 5, filter: .all)
        #expect(sut.items.count == 1)
        #expect(sut.errorMessage == nil)
    }

    // MARK: - Workouts granted, but no measurements

    @Test func workoutsWithoutMeasurements_stillListWithoutNumbers() async {
        // Only "Trainings" granted: the workout exists, but heart rate, distance etc. are hidden
        // (the list item then carries no numbers).
        let sut = exporter(workouts: [workout(daysAgo: 0)])

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.count == 1)
        #expect(sut.items[0].averageHeartRate == nil)
        #expect(sut.items[0].distanceText == nil)
        #expect(sut.errorMessage == nil)
    }

    @Test func exportWithoutAnyMeasurement_showsNotice() {
        let records = [record(metrics: [:]), record(metrics: [:])]

        #expect(WorkoutExporter.missingMetricsNotice(for: records) == HealthMessages.noMetrics)
    }

    @Test func exportWithSomeMeasurements_showsNoNotice() {
        let records = [
            record(metrics: [:]),
            record(metrics: ["heartRate": MetricSummary(unit: "bpm", average: 140)]),
        ]

        #expect(WorkoutExporter.missingMetricsNotice(for: records) == nil)
    }

    @Test func emptyExport_showsNoNotice() {
        #expect(WorkoutExporter.missingMetricsNotice(for: []) == nil)
    }

    // MARK: - Errors

    @Test func healthUnavailable_showsUnavailableMessage() async {
        let sut = exporter(available: false)

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == HealthMessages.unavailable)
        #expect(sut.hasLoaded)
    }

    @Test func accessRequestFails_showsErrorInsteadOfCrashing() async {
        struct Boom: LocalizedError { var errorDescription: String? { "Boom" } }
        let sut = exporter(accessError: Boom())

        await sut.loadList(count: 5, filter: .all)

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == "Boom")
        #expect(!sut.isLoading)
    }

    // MARK: - After an export

    @Test func finishExport_clearsSelectionAndDiscardsTheExport() async {
        let sut = exporter(workouts: [workout(daysAgo: 0), workout(daysAgo: 1), workout(daysAgo: 2)])
        await sut.loadList(count: 5, filter: .all)
        sut.selectedIDs = Set(sut.items.map(\.id))
        #expect(sut.selectedIDs.count == 3)

        sut.finishExport()

        #expect(sut.selectedIDs.isEmpty)
        #expect(sut.jsonURL == nil)
        #expect(sut.csvURL == nil)
        #expect(sut.jsonString == nil)
        // The list itself stays, so the next export can start right away.
        #expect(sut.items.count == 3)
    }

    @Test func confirmationMessage_namesCountAndAction() {
        #expect(ExportConfirmation.message(count: 1, copied: false) == "1 Workout exportiert")
        #expect(ExportConfirmation.message(count: 3, copied: false) == "3 Workouts exportiert")
        #expect(ExportConfirmation.message(count: 2, copied: true) == "2 Workouts kopiert")
    }
}
