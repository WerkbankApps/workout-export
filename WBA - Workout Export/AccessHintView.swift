import SwiftUI

/// Shown once after the welcome page, right before iOS asks for Health access.
struct AccessHintView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink)
                    .padding(.top, 40)

                Text("Gleich fragt Health nach deiner Erlaubnis")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 22) {
                    IntroRow(
                        symbol: "1.circle",
                        title: "Als Nächstes: Health-Zugriff",
                        text: "iOS zeigt gleich eine Liste mit Datentypen. Tippe oben auf „Alle Themen auswählen“ und dann auf „Erlauben“."
                    )
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

                Text("Ändern kannst du das später in der Health-App unter Profilbild › Datenschutz › Apps › Workout Export.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                dismiss()
            } label: {
                Text("Weiter zu Health")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
        // The only way out is the button, so the Health request always follows.
        .interactiveDismissDisabled()
    }
}

#Preview {
    AccessHintView()
}
