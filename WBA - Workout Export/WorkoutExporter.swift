import Foundation
import HealthKit
import Observation

/// Sport filter for the workout query.
enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case running = "Laufen"
    case cycling = "Radfahren"
    case swimming = "Schwimmen"
    case walking = "Gehen/Wandern"
    case strength = "Krafttraining"
    case hiit = "HIIT"

    var id: String { rawValue }

    var activityTypes: [HKWorkoutActivityType] {
        switch self {
        case .all: []
        case .running: [.running]
        case .cycling: [.cycling]
        case .swimming: [.swimming]
        case .walking: [.walking, .hiking]
        case .strength: [.traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining]
        case .hiit: [.highIntensityIntervalTraining]
        }
    }
}

@MainActor
@Observable
final class WorkoutExporter {
    /// Workouts shown in the selection list, newest first.
    var items: [WorkoutListItem] = []
    var selectedIDs: Set<UUID> = [] {
        didSet { clearExport() }
    }
    var jsonURL: URL?
    var csvURL: URL?
    var jsonString: String?
    var isLoading = false
    var isExporting = false
    var hasLoaded = false
    var errorMessage: String?

    private let store = HKHealthStore()
    private let injectedAccess: HealthAccess?
    /// Shown in the export sheet when the exported workouts contain no measurements at all.
    var exportNotice: String?
    private var workoutsByID: [UUID: HKWorkout] = [:]
    private var loadedFilter: WorkoutFilter = .all
    private var isDemo = false

    /// Quantity types exported from workout statistics, with the unit used for the export.
    private static let metricSpecs: [HKQuantityTypeIdentifier: (key: String, unit: HKUnit, label: String)] = {
        let km = HKUnit.meterUnit(with: .kilo)
        let kmh = km.unitDivided(by: .hour())
        let perMinute = HKUnit.count().unitDivided(by: .minute())
        let mets = HKUnit.kilocalorie().unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))
        return [
            .heartRate: ("heartRate", perMinute, "bpm"),
            .activeEnergyBurned: ("activeEnergy", .kilocalorie(), "kcal"),
            .basalEnergyBurned: ("basalEnergy", .kilocalorie(), "kcal"),
            .distanceWalkingRunning: ("distanceWalkingRunning", km, "km"),
            .distanceCycling: ("distanceCycling", km, "km"),
            .distanceSwimming: ("distanceSwimming", .meter(), "m"),
            .distanceRowing: ("distanceRowing", km, "km"),
            .distancePaddleSports: ("distancePaddleSports", km, "km"),
            .distanceCrossCountrySkiing: ("distanceCrossCountrySkiing", km, "km"),
            .distanceDownhillSnowSports: ("distanceDownhillSnowSports", km, "km"),
            .stepCount: ("steps", .count(), "count"),
            .swimmingStrokeCount: ("swimmingStrokes", .count(), "count"),
            .flightsClimbed: ("flightsClimbed", .count(), "count"),
            .runningPower: ("runningPower", .watt(), "W"),
            .cyclingPower: ("cyclingPower", .watt(), "W"),
            .runningSpeed: ("runningSpeed", kmh, "km/h"),
            .cyclingSpeed: ("cyclingSpeed", kmh, "km/h"),
            .cyclingCadence: ("cyclingCadence", perMinute, "rpm"),
            .runningStrideLength: ("runningStrideLength", .meter(), "m"),
            .runningVerticalOscillation: ("runningVerticalOscillation", .meterUnit(with: .centi), "cm"),
            .runningGroundContactTime: ("runningGroundContactTime", .secondUnit(with: .milli), "ms"),
            .physicalEffort: ("physicalEffort", mets, "METs"),
        ]
    }()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.workoutEffortScore),
            HKQuantityType(.estimatedWorkoutEffortScore),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
        ]
        for identifier in Self.metricSpecs.keys {
            types.insert(HKQuantityType(identifier))
        }
        return types
    }

    init(access: HealthAccess? = nil) {
        injectedAccess = access
    }

    private var access: HealthAccess {
        injectedAccess ?? HealthAccess(
            isAvailable: { HKHealthStore.isHealthDataAvailable() },
            requestAccess: { [store, readTypes] in
                try await store.requestAuthorization(toShare: [], read: readTypes)
            },
            fetchWorkouts: { [self] count, filter in
                try await fetchWorkouts(count: count, filter: filter).map {
                    LoadedWorkout(item: makeListItem(for: $0), workout: $0)
                }
            }
        )
    }

    // MARK: - Public

    /// Loads the latest workouts for the selection list and preselects only the newest one.
    func loadList(count: Int, filter: WorkoutFilter) async {
        #if DEBUG
        if isDemo || ProcessInfo.processInfo.arguments.contains("-demoMode") {
            loadDemo(count: count, filter: filter)
            return
        }
        #endif

        let access = access
        guard access.isAvailable() else {
            errorMessage = HealthMessages.unavailable
            hasLoaded = true
            return
        }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            try await access.requestAccess()
            let loaded = try await access.fetchWorkouts(count, filter)
            workoutsByID = Dictionary(uniqueKeysWithValues: loaded.compactMap { entry in
                entry.workout.map { (entry.item.id, $0) }
            })
            items = loaded.map(\.item)
            loadedFilter = filter
            selectedIDs = Set(items.prefix(1).map(\.id))

            if items.isEmpty {
                errorMessage = HealthMessages.noWorkouts
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    /// Builds the export files from the selected workouts only.
    func exportSelected(includeHeartRateSeries: Bool) async {
        let selectedItems = items.filter { selectedIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        isExporting = true
        errorMessage = nil
        exportNotice = nil
        defer { isExporting = false }

        do {
            #if DEBUG
            if isDemo {
                try writeFiles(records: selectedItems.map(Self.demoRecord), context: AthleteContext(restingHeartRateBpm: 52, vo2MaxMlPerKgMin: 48.3), filter: loadedFilter)
                return
            }
            #endif

            var records: [WorkoutRecord] = []
            for item in selectedItems {
                guard let workout = workoutsByID[item.id] else { continue }
                records.append(await makeRecord(for: workout, includeHeartRateSeries: includeHeartRateSeries))
            }
            // A newer export (e.g. after toggling an option) replaced this one.
            guard !Task.isCancelled else { return }

            let context = AthleteContext(
                restingHeartRateBpm: await latestValue(.restingHeartRate, unit: .count().unitDivided(by: .minute())),
                vo2MaxMlPerKgMin: await latestValue(
                    .vo2Max,
                    unit: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
                )
            )
            try writeFiles(records: records, context: context, filter: loadedFilter)
            exportNotice = Self.missingMetricsNotice(for: records)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// After a completed export: back to a clean selection, nothing marked.
    func finishExport() {
        selectedIDs = []
    }

    /// Discards the last export so it never gets out of sync with the current selection or options.
    func clearExport() {
        exportNotice = nil
        jsonURL = nil
        csvURL = nil
        jsonString = nil
    }

    // MARK: - List display

    /// A hint when none of the exported workouts has any measurement (typically: only the workouts
    /// were shared in Health, but not heart rate, distance etc.).
    static func missingMetricsNotice(for records: [WorkoutRecord]) -> String? {
        guard !records.isEmpty, records.allSatisfy({ $0.metrics.isEmpty }) else { return nil }
        return HealthMessages.noMetrics
    }

    private func makeListItem(for workout: HKWorkout) -> WorkoutListItem {
        let summaries = metrics(from: workout.allStatistics)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRate = Self.value(workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity(), bpm)
        let energy = Self.value(workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity(), .kilocalorie())

        return WorkoutListItem(
            id: workout.uuid,
            activityType: workout.workoutActivityType,
            start: workout.startDate,
            duration: workout.duration,
            distanceText: Self.distanceText(from: summaries),
            averageHeartRate: heartRate.map { Int($0.rounded()) },
            activeEnergy: energy.map { Int($0.rounded()) },
            source: workout.sourceRevision.source.name
        )
    }

    /// Total distance as display text, e.g. "8,42 km" or "1.500 m".
    private static func distanceText(from summaries: [String: MetricSummary]) -> String? {
        guard let entry = summaries.first(where: { $0.key.hasPrefix("distance") }),
              let total = entry.value.total, total > 0 else { return nil }
        let digits = entry.value.unit == "m" ? 0 : 2
        return "\(total.formatted(.number.precision(.fractionLength(digits)))) \(entry.value.unit)"
    }

    // MARK: - Demo data

    #if DEBUG
    /// Fills the list with sample workouts for previews and App Store screenshots (launch argument `-demoMode`).
    func loadDemo(count: Int = 5, filter: WorkoutFilter = .all) {
        isDemo = true
        let samples = WorkoutListItem.samples.filter { filter.activityTypes.isEmpty || filter.activityTypes.contains($0.activityType) }
        items = Array(samples.prefix(count))
        loadedFilter = filter
        // Launch argument `-demoSelectCount 3` preselects more workouts for screenshots.
        let selectCount = max(1, UserDefaults.standard.integer(forKey: "demoSelectCount"))
        selectedIDs = Set(items.prefix(selectCount).map(\.id))
        errorMessage = nil
        hasLoaded = true
    }

    private static func demoRecord(from item: WorkoutListItem) -> WorkoutRecord {
        var metrics: [String: MetricSummary] = [:]
        if let averageHeartRate = item.averageHeartRate {
            metrics["heartRate"] = MetricSummary(unit: "bpm", average: Double(averageHeartRate))
        }
        if let activeEnergy = item.activeEnergy {
            metrics["activeEnergy"] = MetricSummary(unit: "kcal", total: Double(activeEnergy))
        }
        return WorkoutRecord(
            id: item.id.uuidString, activityType: name(for: item.activityType),
            start: item.start, end: item.start.addingTimeInterval(item.duration),
            durationMinutes: (item.duration / 60).rounded(to: 1), source: item.source,
            indoor: nil, elevationAscendedMeters: nil, temperatureCelsius: nil, humidityPercent: nil,
            effortScore: nil, estimatedEffortScore: nil, metrics: metrics, activities: nil, heartRatePerMinute: nil
        )
    }
    #endif

    // MARK: - Queries

    private func fetchWorkouts(count: Int, filter: WorkoutFilter) async throws -> [HKWorkout] {
        var predicate: NSPredicate?
        if !filter.activityTypes.isEmpty {
            predicate = NSCompoundPredicate(orPredicateWithSubpredicates: filter.activityTypes.map {
                HKQuery.predicateForWorkouts(with: $0)
            })
        }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: count
        )
        return try await descriptor.result(for: store)
    }

    private func makeRecord(for workout: HKWorkout, includeHeartRateSeries: Bool) async -> WorkoutRecord {
        let metadata = workout.metadata ?? [:]

        // Only export sub-activities for real multi-part workouts; single workouts always contain one.
        var activities: [ActivityRecord]?
        if workout.workoutActivities.count > 1 {
            activities = workout.workoutActivities.map { activity in
                ActivityRecord(
                    activityType: Self.name(for: activity.workoutConfiguration.activityType),
                    start: activity.startDate,
                    end: activity.endDate,
                    durationMinutes: (activity.duration / 60).rounded(to: 1),
                    metrics: metrics(from: activity.allStatistics)
                )
            }
        }

        let humidity = Self.value(metadata[HKMetadataKeyWeatherHumidity] as? HKQuantity, .percent()).map { $0 * 100 }

        return WorkoutRecord(
            id: workout.uuid.uuidString,
            activityType: Self.name(for: workout.workoutActivityType),
            start: workout.startDate,
            end: workout.endDate,
            durationMinutes: (workout.duration / 60).rounded(to: 1),
            source: workout.sourceRevision.source.name,
            indoor: (metadata[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue,
            elevationAscendedMeters: Self.value(metadata[HKMetadataKeyElevationAscended] as? HKQuantity, .meter())?.rounded(to: 0),
            temperatureCelsius: Self.value(metadata[HKMetadataKeyWeatherTemperature] as? HKQuantity, .degreeCelsius())?.rounded(to: 1),
            humidityPercent: humidity?.rounded(to: 0),
            effortScore: await effortScore(.workoutEffortScore, for: workout),
            estimatedEffortScore: await effortScore(.estimatedWorkoutEffortScore, for: workout),
            metrics: metrics(from: workout.allStatistics),
            activities: activities,
            heartRatePerMinute: includeHeartRateSeries ? await heartRatePerMinute(for: workout) : nil
        )
    }

    private func metrics(from statistics: [HKQuantityType: HKStatistics]) -> [String: MetricSummary] {
        var result: [String: MetricSummary] = [:]
        for (type, stats) in statistics {
            guard let spec = Self.metricSpecs[HKQuantityTypeIdentifier(rawValue: type.identifier)] else { continue }
            var summary = MetricSummary(unit: spec.label)
            if type.aggregationStyle == .cumulative {
                summary.total = Self.value(stats.sumQuantity(), spec.unit)?.rounded(to: 2)
            } else {
                summary.average = Self.value(stats.averageQuantity(), spec.unit)?.rounded(to: 1)
                summary.minimum = Self.value(stats.minimumQuantity(), spec.unit)?.rounded(to: 1)
                summary.maximum = Self.value(stats.maximumQuantity(), spec.unit)?.rounded(to: 1)
            }
            result[spec.key] = summary
        }
        return result
    }

    private func effortScore(_ identifier: HKQuantityTypeIdentifier, for workout: HKWorkout) async -> Double? {
        let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return Self.value(sample.quantity, .appleEffortScore())?.rounded(to: 1)
    }

    /// Averages heart rate samples into one-minute buckets starting at the workout start.
    private func heartRatePerMinute(for workout: HKWorkout) async -> [Int?]? {
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.heartRate), predicate: predicate),
            options: .discreteAverage,
            anchorDate: workout.startDate,
            intervalComponents: DateComponents(minute: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return nil }

        let bpm = HKUnit.count().unitDivided(by: .minute())
        let minutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded(.up)))
        var values = [Int?](repeating: nil, count: minutes)
        for stats in collection.statistics() {
            let index = Int(stats.startDate.timeIntervalSince(workout.startDate) / 60)
            guard values.indices.contains(index), let value = Self.value(stats.averageQuantity(), bpm) else { continue }
            values[index] = Int(value.rounded())
        }
        return values.contains { $0 != nil } ? values : nil
    }

    private func latestValue(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return Self.value(sample.quantity, unit)?.rounded(to: 1)
    }

    // MARK: - Export files

    private func writeFiles(records: [WorkoutRecord], context: AthleteContext, filter: WorkoutFilter) throws {
        let export = WorkoutExport(
            exportedAt: .now,
            timeZone: TimeZone.current.identifier,
            filter: filter.rawValue,
            notes: [
                "Workouts sind absteigend nach Datum sortiert (neuestes zuerst).",
                "heartRatePerMinute: durchschnittliche Herzfrequenz pro Minute ab Workout-Start; Index = Minute, null = keine Daten.",
                "effortScore: vom Nutzer erfasste Anstrengung (1–10); estimatedEffortScore: von der Apple Watch geschätzt.",
            ],
            context: context,
            workouts: records
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Date.ISO8601FormatStyle(timeZone: .current).format(date))
        }
        let jsonData = try encoder.encode(export)
        jsonString = String(data: jsonData, encoding: .utf8)

        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let directory = FileManager.default.temporaryDirectory
        let jsonFile = directory.appendingPathComponent("workouts-\(stamp).json")
        let csvFile = directory.appendingPathComponent("workouts-\(stamp).csv")
        try jsonData.write(to: jsonFile, options: .atomic)
        try Self.csv(for: records).write(to: csvFile, atomically: true, encoding: .utf8)
        jsonURL = jsonFile
        csvURL = csvFile
    }

    /// One summary row per workout, for spreadsheets.
    private static func csv(for records: [WorkoutRecord]) -> String {
        let header = "start,end,activityType,durationMin,distanceKm,activeKcal,avgHeartRate,maxHeartRate,elevationAscendedM,effortScore,estimatedEffortScore"
        let isoStyle = Date.ISO8601FormatStyle(timeZone: .current)
        let rows = records.map { record -> String in
            let distance = record.metrics.first { $0.key.hasPrefix("distance") }.map { entry -> Double? in
                guard let total = entry.value.total else { return nil }
                return entry.value.unit == "m" ? total / 1000 : total
            } ?? nil
            let fields: [String] = [
                isoStyle.format(record.start),
                isoStyle.format(record.end),
                record.activityType,
                String(record.durationMinutes),
                format(distance),
                format(record.metrics["activeEnergy"]?.total),
                format(record.metrics["heartRate"]?.average),
                format(record.metrics["heartRate"]?.maximum),
                format(record.elevationAscendedMeters),
                format(record.effortScore),
                format(record.estimatedEffortScore),
            ]
            return fields.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func format(_ value: Double?) -> String {
        value.map { String($0.rounded(to: 2)) } ?? ""
    }

    // MARK: - Helpers

    /// Converts a quantity safely; HealthKit raises an exception for incompatible units.
    private static func value(_ quantity: HKQuantity?, _ unit: HKUnit) -> Double? {
        guard let quantity, quantity.is(compatibleWith: unit) else { return nil }
        return quantity.doubleValue(for: unit)
    }

    static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "running"
        case .walking: "walking"
        case .hiking: "hiking"
        case .cycling: "cycling"
        case .handCycling: "handCycling"
        case .swimming: "swimming"
        case .swimBikeRun: "multisport"
        case .transition: "transition"
        case .rowing: "rowing"
        case .elliptical: "elliptical"
        case .stairClimbing: "stairClimbing"
        case .stairs: "stairs"
        case .traditionalStrengthTraining: "traditionalStrengthTraining"
        case .functionalStrengthTraining: "functionalStrengthTraining"
        case .coreTraining: "coreTraining"
        case .highIntensityIntervalTraining: "hiit"
        case .crossTraining: "crossTraining"
        case .mixedCardio: "mixedCardio"
        case .jumpRope: "jumpRope"
        case .yoga: "yoga"
        case .pilates: "pilates"
        case .flexibility: "flexibility"
        case .mindAndBody: "mindAndBody"
        case .cooldown: "cooldown"
        case .cardioDance: "cardioDance"
        case .socialDance: "socialDance"
        case .boxing: "boxing"
        case .kickboxing: "kickboxing"
        case .martialArts: "martialArts"
        case .climbing: "climbing"
        case .soccer: "soccer"
        case .basketball: "basketball"
        case .tennis: "tennis"
        case .crossCountrySkiing: "crossCountrySkiing"
        case .downhillSkiing: "downhillSkiing"
        case .snowboarding: "snowboarding"
        case .paddleSports: "paddleSports"
        case .other: "other"
        default: "activityType_\(type.rawValue)"
        }
    }
}
