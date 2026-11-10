import HealthKit
import SwiftUI

/// German display names, SF Symbols and colors for the workout list.
extension HKWorkoutActivityType {
    /// Color per sport family, used for the icon circle on each card.
    var tint: Color {
        switch self {
        case .running, .walking, .hiking, .wheelchairRunPace, .wheelchairWalkPace:
            .green
        case .cycling, .handCycling:
            .orange
        case .swimming, .rowing, .paddleSports, .swimBikeRun:
            .cyan
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            .indigo
        case .highIntensityIntervalTraining, .crossTraining, .mixedCardio, .jumpRope, .boxing, .kickboxing, .martialArts:
            .pink
        case .yoga, .pilates, .flexibility, .mindAndBody, .cooldown:
            .teal
        case .crossCountrySkiing, .downhillSkiing, .snowboarding:
            .blue
        default:
            .gray
        }
    }

    var displayName: String {
        switch self {
        case .running: "Laufen"
        case .walking: "Gehen"
        case .hiking: "Wandern"
        case .cycling: "Radfahren"
        case .handCycling: "Handbike"
        case .swimming: "Schwimmen"
        case .swimBikeRun: "Multisport"
        case .transition: "Wechsel"
        case .rowing: "Rudern"
        case .elliptical: "Crosstrainer"
        case .stairClimbing: "Stepper"
        case .stairs: "Treppensteigen"
        case .traditionalStrengthTraining: "Krafttraining"
        case .functionalStrengthTraining: "Funktionelles Krafttraining"
        case .coreTraining: "Core-Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .crossTraining: "Cross-Training"
        case .mixedCardio: "Gemischtes Cardio"
        case .jumpRope: "Seilspringen"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .flexibility: "Beweglichkeit"
        case .mindAndBody: "Mind & Body"
        case .cooldown: "Cooldown"
        case .cardioDance: "Cardio-Tanz"
        case .socialDance: "Tanzen"
        case .boxing: "Boxen"
        case .kickboxing: "Kickboxen"
        case .martialArts: "Kampfsport"
        case .climbing: "Klettern"
        case .soccer: "Fußball"
        case .basketball: "Basketball"
        case .tennis: "Tennis"
        case .crossCountrySkiing: "Langlauf"
        case .downhillSkiing: "Ski Alpin"
        case .snowboarding: "Snowboard"
        case .paddleSports: "Paddeln"
        default: "Sonstiges"
        }
    }

    var symbolName: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .hiking: "figure.hiking"
        case .cycling: "figure.outdoor.cycle"
        case .handCycling: "figure.hand.cycling"
        case .swimming: "figure.pool.swim"
        case .rowing: "figure.rower"
        case .elliptical: "figure.elliptical"
        case .stairClimbing, .stairs: "figure.stairs"
        case .traditionalStrengthTraining: "figure.strengthtraining.traditional"
        case .functionalStrengthTraining: "figure.strengthtraining.functional"
        case .coreTraining: "figure.core.training"
        case .highIntensityIntervalTraining: "figure.highintensity.intervaltraining"
        case .crossTraining: "figure.cross.training"
        case .mixedCardio: "figure.mixed.cardio"
        case .jumpRope: "figure.jumprope"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .flexibility: "figure.flexibility"
        case .mindAndBody: "figure.mind.and.body"
        case .cooldown: "figure.cooldown"
        case .cardioDance, .socialDance: "figure.dance"
        case .boxing: "figure.boxing"
        case .kickboxing: "figure.kickboxing"
        case .martialArts: "figure.martial.arts"
        case .climbing: "figure.climbing"
        case .soccer: "figure.indoor.soccer"
        case .basketball: "figure.basketball"
        case .tennis: "figure.tennis"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .downhillSkiing: "figure.skiing.downhill"
        case .snowboarding: "figure.snowboarding"
        case .paddleSports: "oar.2.crossed"
        default: "figure.mixed.cardio"
        }
    }
}
