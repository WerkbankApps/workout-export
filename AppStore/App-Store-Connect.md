# App Store Connect – Kopiervorlage Workout Export 1.0.0

## Neue App anlegen (Apps › „+“ › Neue App)

| Feld | Wert |
|---|---|
| Plattform | iOS |
| Name | `Workout Export – Werkbank Apps` (30/30 Zeichen) |
| Primäre Sprache | Deutsch |
| Bundle-ID | `de.werkbankapps.workoutexport` |
| SKU | `wba-workout-export` |
| Benutzerzugriff | Uneingeschränkter Zugriff |

## App-Informationen

| Feld | Wert |
|---|---|
| Untertitel | `Workouts aus Health teilen` (26/30) |
| Kategorie | Gesundheit und Fitness |
| Zweite Kategorie | Dienstprogramme (optional) |
| Datenschutzrichtlinie (URL) | `https://werkbankapps.github.io/workout-export/` |
| Altersfreigabe | Fragebogen: überall „Nein“ → 4+ |

## Version 1.0.0

**Werbetext** (170 Zeichen, jederzeit änderbar):

```
Deine Workouts aus Apple Health – gezielt ausgewählt, kompakt exportiert und bereit für die Analyse mit einer KI. Ohne Server, ohne Tracking, Open Source.
```

**Beschreibung:**

```
Exportiere genau die Workouts, die du brauchst – statt deiner kompletten Health-Daten.

Workout Export lädt deine letzten Trainings aus Apple Health. Du wählst die gewünschten aus und erhältst eine kompakte JSON- oder CSV-Datei. Ideal, um dein Training mit einer KI zu analysieren, deinen Trainingsplan anzupassen oder die Werte in einer Tabelle auszuwerten.

ENTHALTENE DATEN
• Sportart, Datum, Dauer und Distanz
• Herzfrequenz (Durchschnitt, Minimum, Maximum) – auf Wunsch Minute für Minute
• Aktive Kalorien, Höhenmeter, Schritte
• Laufleistung, Trittfrequenz, Bodenkontaktzeit und mehr, falls aufgezeichnet
• Anstrengungswert der Apple Watch
• Aktueller Ruhepuls und VO2max als Kontext

SO EINFACH GEHT’S
1. Sportart und Anzahl wählen
2. Workouts antippen
3. Als JSON oder CSV teilen – oder direkt in einen Chat kopieren

DATENSCHUTZ
Alle Daten bleiben auf deinem iPhone. Die App sendet nichts an Server und nutzt keine Werbung oder Analysedienste. Daten verlassen dein Gerät nur, wenn du sie selbst teilst. Der Quellcode ist Open Source und auf GitHub einsehbar.

Eine App von Werkbank Apps.
```

**Schlüsselwörter** (98/100):

```
Health,JSON,CSV,Training,Laufen,Radfahren,Herzfrequenz,Puls,Fitness,KI,Analyse,Trainingsplan,Watch
```

| Feld | Wert |
|---|---|
| Support-URL | `https://werkbankapps.github.io/workout-export/` |
| Marketing-URL | `https://werkbankapps.github.io/` (optional) |
| Copyright | `2026 Christian Gerdes` |
| Screenshots 6,9″ | `Screenshots/iPhone 18 Pro Max/` – Reihenfolge 1 bis 4 |

## App-Datenschutz („Datenschutzangaben“)

- Erfassen Sie Daten von dieser App? → **Nein, wir erfassen keine Daten**

## Preis und Verfügbarkeit

- Preis: **Kostenlos (0,00 €)**
- Verfügbarkeit: alle Länder (oder nur deutschsprachige: DE, AT, CH)

## Hinweise für die App-Prüfung

Kontakt: Christian Gerdes · werkbankapps@icloud.com

```
Workout Export reads workouts and related samples (heart rate, distance, energy, etc.) from HealthKit with read-only access and lets the user export a selection as a JSON or CSV file via the system share sheet or the clipboard. The app has no network code, no accounts, no analytics and no ads; data only leaves the device when the user shares an export file.

To test: grant Health read access when prompted. If the review device has no workouts, please record a short workout (e.g. with the Apple Watch or the Fitness app) or add one in the Health app. The app's UI is in German.

Source code: https://github.com/WerkbankApps/workout-export
```

## Export-Compliance

Verschlüsselung: bereits im Projekt als „keine“ hinterlegt (`ITSAppUsesNonExemptEncryption = NO`) – keine Fragen mehr.
