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
                                copyJSON(file: jsonURL, text: exporter.jsonString)
                                didCopy = true
                                onExported(ExportConfirmation.message(count: exporter.selectedIDs.count, copied: true))
                            } label: {
                                ShareRow(
                                    title: "JSON kopieren",
                                    subtitle: "Als Datei bzw. Text in einen Chat einfügen",
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

                // A tip as plain list footer, so it scrolls with the content at large text sizes.
                Section {
                } footer: {
                    Text("Tipp: Im Teilen-Fenster steht auch AirDrop (zum Mac). Klappt das Teilen mit deiner KI-App nicht wie gewünscht, nimm „JSON kopieren“ und füge den Text in den gewünschten Chat ein.")
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

    /// Puts the JSON on the pasteboard as a file (with name) and as plain text. The target app takes
    /// what it understands: a file becomes an attachment, otherwise the text is pasted.
    private func copyJSON(file: URL, text: String?) {
        if let provider = NSItemProvider(contentsOf: file) {
            if let text {
                provider.registerObject(text as NSString, visibility: .all)
            }
            UIPasteboard.general.itemProviders = [provider]
        } else {
            UIPasteboard.general.string = text
        }
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
    @ScaledMetric(relativeTo: .body) private var iconSize = 36.0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(Color.green.gradient, in: .rect(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    let exporter = WorkoutExporter()
    exporter.loadDemo()
    return ExportSheet(exporter: exporter, onExported: { _ in })
}
#endif
