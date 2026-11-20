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

// MARK: - Welcome page at launch

struct IntroPolicyTests {
    @Test func firstLaunch_alwaysShowsTheIntro() {
        #expect(IntroPolicy.showsAtLaunch(hasSeenIntro: false, showOnLaunch: true))
        #expect(IntroPolicy.showsAtLaunch(hasSeenIntro: false, showOnLaunch: false))
    }

    @Test func laterLaunch_showsTheIntroWhileTheSwitchIsOn() {
        #expect(IntroPolicy.showsAtLaunch(hasSeenIntro: true, showOnLaunch: true))
    }

    @Test func laterLaunch_skipsTheIntroWhenSwitchedOff() {
        #expect(!IntroPolicy.showsAtLaunch(hasSeenIntro: true, showOnLaunch: false))
    }
}

// MARK: - Export format

/// The JSON and CSV files are what other tools (and AI chats) rely on, so their shape must not change by accident.
@MainActor
struct ExportFormatTests {

    private func record(
        activityType: String = "running",
        metrics: [String: MetricSummary] = [:],
        elevation: Double? = nil
    ) -> WorkoutRecord {
        WorkoutRecord(
            id: UUID().uuidString, activityType: activityType,
            start: .now, end: .now.addingTimeInterval(2_880), durationMinutes: 48, source: "Test",
            indoor: nil, elevationAscendedMeters: elevation, temperatureCelsius: nil, humidityPercent: nil,
            effortScore: nil, estimatedEffortScore: nil, metrics: metrics, activities: nil, heartRatePerMinute: nil
        )
    }

    private func demoExporter() -> WorkoutExporter {
        let sut = WorkoutExporter(access: HealthAccess(
            isAvailable: { true }, requestAccess: {}, fetchWorkouts: { _, _ in [] }
        ))
        sut.loadDemo(count: 5, filter: .all)
        return sut
    }

    // MARK: CSV

    @Test func csv_startsWithTheDocumentedHeader() {
        let lines = WorkoutExporter.csv(for: []).split(separator: "\n")

        #expect(lines.count == 1)
        #expect(lines.first == "start,end,activityType,durationMin,distanceKm,activeKcal,avgHeartRate,maxHeartRate,elevationAscendedM,effortScore,estimatedEffortScore")
    }

    @Test func csv_hasOneRowPerWorkout() {
        let lines = WorkoutExporter.csv(for: [record(), record(), record()]).split(separator: "\n")

        #expect(lines.count == 4)
    }

    @Test func csv_convertsDistanceToKilometersAndKeepsMetrics() {
        let metrics = [
            "distanceWalkingRunning": MetricSummary(unit: "m", total: 8_420),
            "activeEnergy": MetricSummary(unit: "kcal", total: 612),
            "heartRate": MetricSummary(unit: "bpm", average: 152, maximum: 171),
        ]

        let row = WorkoutExporter.csv(for: [record(metrics: metrics, elevation: 35)]).split(separator: "\n")[1]
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields.count == 11)
        #expect(fields[2] == "running")
        #expect(fields[3] == "48.0")
        #expect(fields[4] == "8.42")
        #expect(fields[5] == "612.0")
        #expect(fields[6] == "152.0")
        #expect(fields[7] == "171.0")
        #expect(fields[8] == "35.0")
    }

    @Test func csv_leavesMissingValuesEmpty() {
        let row = WorkoutExporter.csv(for: [record()]).split(separator: "\n")[1]
        let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)

        #expect(fields.count == 11)
        let allEmpty = fields[4...].allSatisfy { $0.isEmpty }
        #expect(allEmpty)
    }

    // MARK: JSON

    @Test func json_hasTheDocumentedTopLevelStructure() async throws {
        let sut = demoExporter()

        await sut.exportSelected(includeHeartRateSeries: false)

        let text = try #require(sut.jsonString)
        let root = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        for key in ["exportedAt", "timeZone", "filter", "notes", "context", "workouts"] {
            #expect(root[key] != nil, "missing key \(key)")
        }
        let workouts = try #require(root["workouts"] as? [[String: Any]])
        #expect(workouts.count == sut.selectedIDs.count)
        let first = try #require(workouts.first)
        for key in ["id", "activityType", "start", "end", "durationMinutes", "metrics"] {
            #expect(first[key] != nil, "missing key \(key)")
        }
    }

    @Test func json_writesDatesAsIso8601WithTime() async throws {
        let sut = demoExporter()

        await sut.exportSelected(includeHeartRateSeries: false)

        let text = try #require(sut.jsonString)
        let root = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let first = try #require((root["workouts"] as? [[String: Any]])?.first)
        let start = try #require(first["start"] as? String)
        #expect(start.contains("T"))
        #expect(start.count >= 19)
    }

    @Test func export_onlyContainsTheSelectedWorkouts() async throws {
        let sut = demoExporter()
        sut.selectedIDs = Set(sut.items.prefix(2).map(\.id))

        await sut.exportSelected(includeHeartRateSeries: false)

        let text = try #require(sut.jsonString)
        let root = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect((root["workouts"] as? [[String: Any]])?.count == 2)
    }

    @Test func export_writesBothFilesWithMatchingContent() async throws {
        let sut = demoExporter()

        await sut.exportSelected(includeHeartRateSeries: false)

        let jsonURL = try #require(sut.jsonURL)
        let csvURL = try #require(sut.csvURL)
        #expect(jsonURL.pathExtension == "json")
        #expect(csvURL.pathExtension == "csv")
        let jsonFile = try String(contentsOf: jsonURL, encoding: .utf8)
        let csvFile = try String(contentsOf: csvURL, encoding: .utf8)
        #expect(jsonFile == sut.jsonString)
        #expect(csvFile.hasPrefix("start,end,activityType"))
    }

    @Test func changingTheSelection_discardsTheExport() async throws {
        let sut = demoExporter()
        await sut.exportSelected(includeHeartRateSeries: false)
        #expect(sut.jsonURL != nil)

        sut.toggleSelection(sut.items[1].id)

        #expect(sut.jsonURL == nil)
        #expect(sut.csvURL == nil)
        #expect(sut.jsonString == nil)
    }

    @Test func exportWithNothingSelected_createsNoFiles() async {
        let sut = demoExporter()
        sut.selectedIDs = []

        await sut.exportSelected(includeHeartRateSeries: false)

        #expect(sut.jsonURL == nil)
        #expect(sut.jsonString == nil)
    }
}
