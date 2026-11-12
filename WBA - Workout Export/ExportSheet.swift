import SwiftUI
import UIKit

/// Creates the export for the selected workouts and offers the ways to share it.
struct ExportSheet: View {
    let exporter: WorkoutExporter
    /// Called once the export is really done (shared or copied), with the text for the confirmation.
    let onExported: (String) -> Void
    @State private var shareItem: ShareItem?
    @AppStorage("includeHeartRateSeries") private var includeHeartRateSeries = true
    @State private var didCopy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $includeHeartRateSeries) {
                        Label("Herzfrequenz pro Minute", systemImage: "waveform.path.ecg")
                    }
                } footer: {
                    Text("Mehr Details für die Analyse, die Datei wird dadurch etwas größer.")
                }

                Section {
                    if exporter.isExporting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Export wird erstellt …")
                                .foregroundStyle(.secondary)
                        }
                    } else if let jsonURL = exporter.jsonURL, let csvURL = exporter.csvURL {
                        Group {
                            Button {
                                shareItem = ShareItem(url: jsonURL)
                            } label: {
                                ShareRow(title: "JSON teilen", subtitle: "Ideal für die KI-Analyse", symbol: "curlybraces")
                            }
                            Button {
                                shareItem = ShareItem(url: csvURL)
                            } label: {
                                ShareRow(title: "CSV teilen", subtitle: "Für Numbers oder Excel", symbol: "tablecells")
                            }
                            Button {
                                UIPasteboard.general.string = exporter.jsonString
                                didCopy = true
                                onExported(ExportConfirmation.message(count: exporter.selectedIDs.count, copied: true))
                            } label: {
                                ShareRow(
                                    title: "JSON kopieren",
                                    subtitle: "Direkt in einen Chat einfügen",
                                    symbol: "doc.on.doc"
                                )
                            }
                        }
                        // Neutral text color for the rows; the icons carry the green.
                        .tint(.primary)
                    } else if let errorMessage = exporter.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Teilen")
                } footer: {
                    if let notice = exporter.exportNotice, !exporter.isExporting {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if let jsonString = exporter.jsonString, !exporter.isExporting {
                        Text("JSON-Datei: \(Int64(jsonString.utf8.count).formatted(.byteCount(style: .file)))")
                    }
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", systemImage: "checkmark") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(url: item.url) { completed in
                    shareItem = nil
                    if completed {
                        onExported(ExportConfirmation.message(count: exporter.selectedIDs.count, copied: false))
                    }
                }
                .presentationDetents([.medium, .large])
            }
            // Runs on appear and again whenever the option changes.
            .task(id: includeHeartRateSeries) {
                didCopy = false
                await exporter.exportSelected(includeHeartRateSeries: includeHeartRateSeries)
            }
        }
        .tint(.green)
    }

    private var titleText: String {
        let count = exporter.selectedIDs.count
        return count == 1 ? "1 Workout exportieren" : "\(count) Workouts exportieren"
    }
}

private struct ShareRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.green.gradient, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview {
    let exporter = WorkoutExporter()
    exporter.loadDemo()
    return ExportSheet(exporter: exporter, onExported: { _ in })
}
#endif
