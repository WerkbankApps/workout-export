import SwiftUI
import UIKit

/// A file to hand to the system share sheet.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet, wrapped so the app learns whether sharing was completed or cancelled
/// (SwiftUI's `ShareLink` has no completion callback).
struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The wording of the confirmation shown after an export.
enum ExportConfirmation {
    static func message(count: Int, copied: Bool) -> String {
        let workouts = count == 1 ? "1 Workout" : "\(count) Workouts"
        return copied ? "\(workouts) kopiert" : "\(workouts) exportiert"
    }
}
