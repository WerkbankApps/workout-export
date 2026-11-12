import HealthKit

/// The three things the exporter needs from Health. Tests replace them to simulate granted or denied access.
struct HealthAccess {
    var isAvailable: () -> Bool
    var requestAccess: () async throws -> Void
    var fetchWorkouts: (_ count: Int, _ filter: WorkoutFilter) async throws -> [LoadedWorkout]
}

/// A workout for the list. `workout` is the HealthKit object needed for the export; tests leave it `nil`
/// so they don't have to create `HKWorkout` objects (their initializer is deprecated).
struct LoadedWorkout {
    let item: WorkoutListItem
    let workout: HKWorkout?
}

/// User-facing texts for missing data. HealthKit never tells an app whether read access was denied
/// (privacy by design), so "no workouts" and "access denied" look the same and share one message.
enum HealthMessages {
    static let unavailable = "Health-Daten sind auf diesem Gerät nicht verfügbar."

    static let noWorkouts = """
        Keine Workouts gefunden. Entweder gibt es noch keine, oder der Zugriff ist nicht freigegeben. \
        Gib unter Einstellungen › Apps › Health › Datenzugriff & Geräte › Workout Export alle Daten frei, \
        die im Export enthalten sein sollen (mindestens „Trainings“), und lade die Liste dann neu. \
        Alternativ: Health-App › Profilbild › Datenschutz › Apps › Workout Export.
        """

    static let noMetrics = """
        Keine Messwerte gefunden (z. B. Herzfrequenz oder Distanz). Entweder wurden sie nicht aufgezeichnet, \
        oder der Zugriff ist nicht freigegeben: Einstellungen › Apps › Health › Datenzugriff & Geräte › Workout Export.
        """
}
