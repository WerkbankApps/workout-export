import SwiftUI

struct ContentView: View {
    @State private var exporter = WorkoutExporter()
    @State private var workoutCount = 5
    @State private var filter: WorkoutFilter = .all
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @State private var showIntro = false
    @State private var showExport = false

    private static let countOptions = [5, 10, 20, 50, 100]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar
                    content
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await reload() }
            .navigationTitle("Workout Export")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Info", systemImage: "info.circle") {
                        showIntro = true
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !exporter.items.isEmpty {
                    exportBar
                }
            }
            .sheet(isPresented: $showIntro, onDismiss: introDismissed) {
                IntroView()
            }
            .sheet(isPresented: $showExport) {
                ExportSheet(exporter: exporter)
                    .presentationDetents([.medium, .large])
            }
            .task {
                if hasSeenIntro {
                    await reload()
                } else {
                    showIntro = true
                }
            }
            .onChange(of: filter) { Task { await reload() } }
            .onChange(of: workoutCount) { Task { await reload() } }
        }
        .tint(.green)
    }

    // MARK: - Sections

    /// Horizontally scrolling chips for the number of workouts and the sport filter.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Anzahl", selection: $workoutCount) {
                        ForEach(Self.countOptions, id: \.self) { count in
                            Text("Letzte \(count)").tag(count)
                        }
                    }
                } label: {
                    Label("Letzte \(workoutCount)", systemImage: "chevron.down")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.glass)

                Divider()
                    .frame(height: 24)

                ForEach(WorkoutFilter.allCases) { option in
                    if option == filter {
                        Button(option.rawValue) { filter = option }
                            .buttonStyle(.glassProminent)
                    } else {
                        Button(option.rawValue) { filter = option }
                            .buttonStyle(.glass)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        if exporter.items.isEmpty {
            if exporter.isLoading || !exporter.hasLoaded {
                ProgressView("Workouts werden geladen …")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                ContentUnavailableView {
                    Label("Keine Workouts", systemImage: "figure.run")
                } description: {
                    Text(exporter.errorMessage ?? "Für diesen Filter wurden keine Workouts gefunden.")
                } actions: {
                    Button("Erneut laden") {
                        Task { await reload() }
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 40)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(exporter.selectedIDs.count) von \(exporter.items.count) ausgewählt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(allSelected ? "Keine" : "Alle") {
                        withAnimation(.snappy) {
                            exporter.selectedIDs = allSelected ? [] : Set(exporter.items.map(\.id))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 4)

                LazyVStack(spacing: 10) {
                    ForEach(exporter.items) { item in
                        let isSelected = exporter.selectedIDs.contains(item.id)
                        Button {
                            withAnimation(.snappy) {
                                exporter.toggleSelection(item.id)
                            }
                        } label: {
                            WorkoutCard(item: item, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: isSelected)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var exportBar: some View {
        let count = exporter.selectedIDs.count
        return Button {
            showExport = true
        } label: {
            Label(
                count == 1 ? "1 Workout exportieren" : "\(count) Workouts exportieren",
                systemImage: "square.and.arrow.up"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(count == 0)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private var allSelected: Bool {
        exporter.selectedIDs.count == exporter.items.count
    }

    private func reload() async {
        await exporter.loadList(count: workoutCount, filter: filter)
    }

    private func introDismissed() {
        hasSeenIntro = true
        if !exporter.hasLoaded {
            Task { await reload() }
        }
    }
}

// MARK: - Workout card

private struct WorkoutCard: View {
    let item: WorkoutListItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.activityType.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(item.activityType.tint.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.activityType.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Self.dateText(for: item.start))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label(Duration.seconds(item.duration).formatted(.time(pattern: .hourMinute)) + " h", systemImage: "clock")
                    if let distanceText = item.distanceText {
                        Label(distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    if let heartRate = item.averageHeartRate {
                        Label("\(heartRate)", systemImage: "heart.fill")
                            .symbolRenderingMode(.multicolor)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle())

                Text(item.source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.green : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.green, lineWidth: isSelected ? 2 : 0)
        }
        .contentShape(.rect(cornerRadius: 22))
    }

    /// "Heute, 07:32", "Gestern, 18:10" or "Mo., 3. Nov., 08:05".
    private static func dateText(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Heute, \(time)"
        }
        if calendar.isDateInYesterday(date) {
            return "Gestern, \(time)"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}

// MARK: - Label styles

/// Icon and text close together, for the stats row on each card.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// Text first, icon after it, e.g. for the "Letzte 5 ⌄" chip.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
                .imageScale(.small)
        }
    }
}

#if DEBUG
#Preview("Mit Beispieldaten") {
    let exporter = WorkoutExporter()
    exporter.loadDemo()
    return ContentView.preview(exporter: exporter)
}

extension ContentView {
    /// Preview helper that skips the intro and uses the given exporter.
    static func preview(exporter: WorkoutExporter) -> some View {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        return ContentView(exporter: exporter)
    }

    init(exporter: WorkoutExporter) {
        _exporter = State(initialValue: exporter)
    }
}
#endif
