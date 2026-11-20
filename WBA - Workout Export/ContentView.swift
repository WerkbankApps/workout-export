import SwiftUI

struct ContentView: View {
    @State private var exporter = WorkoutExporter()
    @State private var workoutCount = 5
    @State private var filter: WorkoutFilter = .all
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false
    @AppStorage("showIntroOnLaunch") private var showIntroOnLaunch = true
    @State private var showIntro = false
    @State private var showAccessHint = false
    @State private var showAccessHelp = false
    @State private var showExport = false
    @State private var confirmation: String?
    #if DEBUG && targetEnvironment(simulator)
    @State private var seedReport: String?
    #endif

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
                #if DEBUG && targetEnvironment(simulator)
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Testdaten", systemImage: "wrench.and.screwdriver") {
                        Button("Testdaten erzeugen", systemImage: "plus.circle") { runSeeder(remove: false) }
                        Button("Testdaten entfernen", systemImage: "trash", role: .destructive) { runSeeder(remove: true) }
                    }
                    .tint(.orange)
                }
                #endif
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Info", systemImage: "info.circle") {
                        showIntro = true
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Hidden while the export sheet is open, so it doesn't shine through the glass.
                if !exporter.items.isEmpty && !showExport {
                    exportBar
                }
            }
            .overlay(alignment: .top) {
                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .sensoryFeedback(.success, trigger: confirmation)
            #if DEBUG && targetEnvironment(simulator)
            .overlay(alignment: .bottom) {
                if let seedReport {
                    Text(seedReport + "\n(Tippen zum Schließen)")
                        .font(.caption.monospaced())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.9), in: .rect(cornerRadius: 12))
                        .padding()
                        .onTapGesture { self.seedReport = nil }
                }
            }
            #endif
            .sheet(isPresented: $showIntro, onDismiss: introDismissed) {
                IntroView()
            }
            .sheet(isPresented: $showAccessHint, onDismiss: loadIfNeeded) {
                AccessHintView(isFirstLaunch: true)
            }
            .sheet(isPresented: $showAccessHelp) {
                AccessHintView()
            }
            .sheet(isPresented: $showExport) {
                ExportSheet(exporter: exporter, onExported: exportFinished)
                    .presentationDetents([.medium, .large])
            }
            .task {
                #if DEBUG
                applyScreenshotFilter()
                #endif
                // The welcome page returns at every start unless switched off on the page itself.
                if IntroPolicy.showsAtLaunch(hasSeenIntro: hasSeenIntro, showOnLaunch: showIntroOnLaunch) {
                    showIntro = true
                } else {
                    await reload()
                }
                #if DEBUG
                await applyScreenshotExport()
                #endif
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
                .accessibilityLabel("Anzahl")
                .accessibilityValue("Letzte \(workoutCount)")

                Divider()
                    .frame(height: 24)

                ForEach(WorkoutFilter.allCases) { option in
                    if option == filter {
                        Button(option.rawValue) { filter = option }
                            .buttonStyle(.glassProminent)
                            .accessibilityAddTraits(.isSelected)
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
                    Text(exporter.errorMessage ?? HealthMessages.noWorkouts)
                } actions: {
                    Button("Erneut laden") {
                        Task { await reload() }
                    }
                    .buttonStyle(.glassProminent)
                    Button("Hinweise zum Health-Zugriff") {
                        showAccessHelp = true
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

    #if DEBUG && targetEnvironment(simulator)
    /// Simulator only: fills Health with sample workouts, or removes them again. Started by a button, so the
    /// Health permission sheet appears while the person is looking at the screen (it times out otherwise).
    private func runSeeder(remove: Bool) {
        Task {
            seedReport = remove ? await HealthSeeder.reset() : await HealthSeeder.seed()
            await reload()
        }
    }
    #endif

    #if DEBUG
    // Launch arguments for App Store screenshots, e.g.
    // -demoMode -hasSeenIntro YES -demoFilter Laufen -demoSelectCount 3 -demoShowExport YES
    private func applyScreenshotFilter() {
        if let name = UserDefaults.standard.string(forKey: "demoFilter"),
           let option = WorkoutFilter(rawValue: name) {
            filter = option
        }
    }

    private func applyScreenshotExport() async {
        guard UserDefaults.standard.bool(forKey: "demoShowExport") else { return }
        try? await Task.sleep(for: .milliseconds(800))
        showExport = true
    }
    #endif

    /// First launch: the access hint follows the welcome page and loading starts after it.
    /// Later (info button): just make sure the list is loaded.
    private func introDismissed() {
        let firstLaunch = !hasSeenIntro
        hasSeenIntro = true
        if firstLaunch {
            showAccessHint = true
        } else {
            loadIfNeeded()
        }
    }

    /// Export done: close the sheet, clear the selection and confirm for a moment.
    private func exportFinished(_ message: String) {
        showExport = false
        exporter.finishExport()
        withAnimation(.snappy) { confirmation = message }
        // The banner is only visible for a moment, so VoiceOver gets the message spoken as well.
        AccessibilityNotification.Announcement(message).post()
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.snappy) { confirmation = nil }
        }
    }

    private func loadIfNeeded() {
        if !exporter.hasLoaded {
            Task { await reload() }
        }
    }
}

// MARK: - Workout card

private struct WorkoutCard: View {
    let item: WorkoutListItem
    let isSelected: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The icon circle grows with the text size.
    @ScaledMetric(relativeTo: .title3) private var iconSize = 48.0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.activityType.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(item.activityType.tint.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                // At accessibility sizes the date moves below the name instead of squeezing it.
                let titleLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                titleLayout {
                    Text(item.activityType.displayName)
                        .font(.headline)
                    if !typeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                    }
                    Text(Self.dateText(for: item.start))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                let statsLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(spacing: 12))
                statsLayout {
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
                    .foregroundStyle(.secondary)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.green : Color(.systemGray))
                .contentTransition(.symbolEffect(.replace))
        }
        // One spoken sentence per card instead of loose fragments such as "152".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenDescription)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.green, lineWidth: isSelected ? 2 : 0)
        }
        .contentShape(.rect(cornerRadius: 22))
    }

    /// "Laufen, Heute, 07:32, Dauer 48 Minuten, Distanz 8,42 km, Puls 152, Quelle Apple Watch"
    private var spokenDescription: String {
        var parts = [
            item.activityType.displayName,
            Self.dateText(for: item.start),
            "Dauer " + Duration.seconds(item.duration).formatted(.units(allowed: [.hours, .minutes], width: .wide)),
        ]
        if let distanceText = item.distanceText {
            parts.append("Distanz \(distanceText)")
        }
        if let heartRate = item.averageHeartRate {
            parts.append("Durchschnittspuls \(heartRate) Schläge pro Minute")
        }
        parts.append("Quelle \(item.source)")
        return parts.joined(separator: ", ")
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
