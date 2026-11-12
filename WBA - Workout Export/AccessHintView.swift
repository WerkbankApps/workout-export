import SwiftUI

/// Explains how Health access works. Shown once after the welcome page (right before iOS asks for access)
/// and again from the empty state, when nothing could be loaded.
struct AccessHintView: View {
    /// First launch: iOS asks for access right after this page. Otherwise it explains how to change it.
    var isFirstLaunch = false
    @Environment(\.dismiss) private var dismiss

    private static let settingsPath = "Einstellungen › Apps › Health › Datenzugriff & Geräte › Workout Export"

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink)
                    .padding(.top, 40)

                Text(isFirstLaunch ? "Gleich fragt Health nach deiner Erlaubnis" : "So klappt der Health-Zugriff")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 22) {
                    if isFirstLaunch {
                        IntroRow(
                            symbol: "1.circle",
                            title: "Als Nächstes: Health-Zugriff",
                            text: "iOS zeigt gleich eine Liste mit Datentypen. Tippe oben auf „Alle Themen auswählen“ und dann auf „Erlauben“."
                        )
                    } else {
                        IntroRow(
                            symbol: "gearshape",
                            title: "Zugriff in den Einstellungen freigeben",
                            text: "Öffne \(Self.settingsPath) und schalte die Daten ein, die im Export enthalten sein sollen – am besten alle."
                        )
                    }
                    IntroRow(
                        symbol: "figure.run.circle",
                        title: "Mindestens „Trainings“",
                        text: "„Trainings“ muss freigegeben sein, sonst kann die App nichts anzeigen. Herzfrequenz, Distanz, Energie und mehr sind Zusatzwerte für den Export."
                    )
                    IntroRow(
                        symbol: "checkmark.circle",
                        title: "Ein gespeichertes Workout",
                        text: "In Health muss mindestens ein Workout gespeichert sein, zum Beispiel von der Apple Watch oder aus der Fitness-App."
                    )
                }
                .padding(.horizontal)

                if isFirstLaunch {
                    Text("Ändern kannst du das später unter \(Self.settingsPath).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Alternativ in der Health-App: Profilbild › Datenschutz › Apps › Workout Export. Danach die Liste in Workout Export neu laden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text(isFirstLaunch ? "Weiter zu Health" : "Verstanden")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
        // First launch: the only way out is the button, so the Health request always follows.
        .interactiveDismissDisabled(isFirstLaunch)
    }
}

#Preview("Erster Start") {
    AccessHintView(isFirstLaunch: true)
}

#Preview("Später") {
    AccessHintView()
}
