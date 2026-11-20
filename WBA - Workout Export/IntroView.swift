import SwiftUI

/// Short explanation shown on first launch and via the info button.
struct IntroView: View {
    @Environment(\.dismiss) private var dismiss
    /// Whether this page appears again at the next app start. On by default.
    @AppStorage("showIntroOnLaunch") private var showOnLaunch = true

    var body: some View {
        // Scrolls on small screens or large text sizes instead of truncating.
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .padding(.top, 40)
                    .accessibilityHidden(true)

                Text("Willkommen bei Workout Export")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                rows
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Toggle("Beim nächsten Start wieder anzeigen", isOn: $showOnLaunch)
                    .font(.subheadline)
                    .tint(.green)
                Button {
                    dismiss()
                } label: {
                    Text("Los geht’s")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 22) {
            IntroRow(
                symbol: "list.bullet.circle",
                title: "Workouts auswählen",
                text: "Lade deine letzten Workouts aus Health und wähle genau die aus, die du exportieren möchtest."
            )
            IntroRow(
                symbol: "square.and.arrow.up.circle",
                title: "Kompakt exportieren",
                text: "Statt des kompletten Health-Exports bekommst du eine kleine JSON- oder CSV-Datei, ideal zur Analyse mit einer KI oder in einer Tabelle."
            )
            IntroRow(
                symbol: "heart.circle",
                title: "Health-Zugriff freigeben",
                text: "Gib gleich alles frei, was im Export enthalten sein soll – am besten alle Daten. Später änderst du das unter Einstellungen › Apps › Health › Datenzugriff & Geräte › Workout Export."
            )
            IntroRow(
                symbol: "lock.circle",
                title: "Deine Daten bleiben bei dir",
                text: "Die App liest nur und sendet nichts an Server. Daten verlassen dein iPhone nur, wenn du sie selbst teilst."
            )
        }
        .padding(.horizontal)
    }
}

/// Decides whether the welcome page opens at app start.
enum IntroPolicy {
    /// The first launch always shows it; later launches only while "Beim nächsten Start wieder anzeigen" is on.
    static func showsAtLaunch(hasSeenIntro: Bool, showOnLaunch: Bool) -> Bool {
        !hasSeenIntro || showOnLaunch
    }
}

struct IntroRow: View {
    let symbol: String
    let title: String
    let text: String

    @ScaledMetric(relativeTo: .title) private var iconWidth = 36.0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(.green)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    IntroView()
}
