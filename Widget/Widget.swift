import WidgetKit
import SwiftUI
import AppIntents

@main
struct ScrutinyMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScrutinyMonitorWidget()
    }
}

struct ScrutinyMonitorWidget: Widget {
    let kind: String = "ScrutinyMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScrutinyMonitorWidgetProvider()) { entry in
            ScrutinyMonitorWidgetView(entry: entry)
        }
        .configurationDisplayName("Drive Health")
        .description("Pin overall drive health and temperature statistics directly to your macOS desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Entry
struct ScrutinyMonitorWidgetEntry: TimelineEntry {
    let date: Date
    let installations: [ScrutinyInstallation]
    let totals: OverviewTotals

    // ⚡️ Bolt: Cache computed properties to avoid O(N) recalculation on every widget render cycle
    let averageTemperature: Int?
    let sortedDrives: [OverviewDrive]
    let maxLastRefreshDate: Date?

    init(date: Date, installations: [ScrutinyInstallation], totals: OverviewTotals) {
        self.date = date
        self.installations = installations
        self.totals = totals

        var sum = 0
        var count = 0
        var list = [OverviewDrive]()
        var maxRefreshDate: Date? = nil

        for inst in installations {
            if let devices = inst.lastSnapshot?.devices {
                for dev in devices {
                    if let temp = dev.temperature {
                        sum += temp
                        count += 1
                    }
                    list.append(OverviewDrive(installation: inst, drive: dev))
                }
            }

            if let refreshDate = inst.lastRefreshDate {
                maxRefreshDate = max(maxRefreshDate ?? refreshDate, refreshDate)
            }
        }

        self.averageTemperature = count > 0 ? sum / count : nil
        self.sortedDrives = list.sorted { (lhs: OverviewDrive, rhs: OverviewDrive) in
            if lhs.drive.status != rhs.drive.status {
                return lhs.drive.status.sortRank < rhs.drive.status.sortRank
            }
            return lhs.drive.name.localizedStandardCompare(rhs.drive.name) == .orderedAscending
        }
        self.maxLastRefreshDate = maxRefreshDate
    }
}

// MARK: - Entry Extensions for Shared Logic
extension ScrutinyMonitorWidgetEntry {
    func statusColor(for status: DriveStatus) -> Color {
        switch status {
        case .passed: return .green
        case .warning: return .orange
        case .failed: return .red
        case .unknown: return .secondary
        }
    }

    func tempColor(for temp: Int) -> Color {
        if temp >= 50 {
            return .red
        } else if temp >= 40 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Timeline Provider
struct ScrutinyMonitorWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScrutinyMonitorWidgetEntry {
        let dummy = ScrutinyInstallation.previewInstallations
        return ScrutinyMonitorWidgetEntry(
            date: Date(),
            installations: dummy,
            totals: OverviewTotals(installations: dummy)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScrutinyMonitorWidgetEntry) -> ()) {
        let installations = InstallationPersistence(userDefaults: .shared).load()
        let entry = ScrutinyMonitorWidgetEntry(
            date: Date(),
            installations: installations,
            totals: OverviewTotals(installations: installations)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScrutinyMonitorWidgetEntry>) -> ()) {
        let installations = InstallationPersistence(userDefaults: .shared).load()
        let entry = ScrutinyMonitorWidgetEntry(
            date: Date(),
            installations: installations,
            totals: OverviewTotals(installations: installations)
        )
        // Refresh widget every 15 minutes
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }
}

// MARK: - App Intent for Interactive Refresh
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Health Data"
    static var description = IntentDescription("Fetches latest drive statistics from all configured Scrutiny servers.")

    func perform() async throws -> some IntentResult {
        let persistence = InstallationPersistence(userDefaults: .shared)
        let installations = persistence.load()
        
        guard !installations.isEmpty else {
            return .result()
        }

        let client = ScrutinyClient()

        // Asynchronously fetch status updates from all servers concurrently
        await withTaskGroup(of: (UUID, Result<InstallationSnapshot, Error>).self) { group in
            for inst in installations {
                group.addTask {
                    do {
                        let snapshot = try await client.fetchSnapshot(for: inst)
                        return (inst.id, .success(snapshot))
                    } catch {
                        return (inst.id, .failure(error))
                    }
                }
            }

            var refreshed = installations

            // ⚡ Bolt: Create an O(1) lookup dictionary to map UUID to array index.
            // This prevents an O(N) array scan on every loop iteration, reducing
            // overall time complexity from O(N^2) to O(N).
            var idToIndex = [UUID: Int]()
            idToIndex.reserveCapacity(refreshed.count)
            for (idx, inst) in refreshed.enumerated() {
                idToIndex[inst.id] = idx
            }

            for await result in group {
                guard let idx = idToIndex[result.0] else { continue }
                switch result.1 {
                case .success(let snapshot):
                    refreshed[idx].lastSnapshot = snapshot
                    refreshed[idx].lastRefreshDate = Date()
                    refreshed[idx].lastError = nil
                case .failure(let error):
                    refreshed[idx].lastError = error.secureDescription
                }
            }

            persistence.save(refreshed)
        }

        // Notify WidgetKit to reload UI timelines
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

// MARK: - Widget View Wrapper
struct ScrutinyMonitorWidgetView: View {
    var entry: ScrutinyMonitorWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackgroundView(totals: entry.totals)
        }
    }
}

// MARK: - Shared Aesthetic Elements
struct WidgetBackgroundView: View {
    var totals: OverviewTotals

    var body: some View {
        ZStack {
            // Dynamic premium backdrop gradient based on drive failure severity
            if totals.failedCount > 0 {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor).opacity(0.95),
                        Color(red: 0.18, green: 0.04, blue: 0.05).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if totals.warningCount > 0 {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor).opacity(0.95),
                        Color(red: 0.16, green: 0.10, blue: 0.03).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor).opacity(0.95),
                        Color(red: 0.03, green: 0.12, blue: 0.08).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    var entry: ScrutinyMonitorWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                statusIndicator
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                metricLabel(value: "\(entry.totals.driveCount)", symbol: "externaldrive", tooltip: "Total Drives")
                if let avgTemp = entry.averageTemperature {
                    Spacer()
                    metricLabel(value: "\(avgTemp)°C", symbol: "thermometer.medium", tooltip: "Avg Temp")
                }
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if entry.totals.failedCount > 0 {
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(.red)
                .font(.title2)
                .shadow(color: .red.opacity(0.5), radius: 4)
        } else if entry.totals.warningCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)
                .shadow(color: .orange.opacity(0.5), radius: 4)
        } else if entry.totals.installationCount == 0 {
            Image(systemName: "tray")
                .foregroundColor(.secondary)
                .font(.title2)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
                .shadow(color: .green.opacity(0.5), radius: 4)
        }
    }

    private var statusTitle: String {
        if entry.totals.failedCount > 0 {
            return "\(entry.totals.failedCount) Critical"
        } else if entry.totals.warningCount > 0 {
            return "\(entry.totals.warningCount) Warning"
        } else if entry.totals.installationCount == 0 {
            return "No Servers"
        } else {
            return "Drives OK"
        }
    }

    private var statusSubtitle: String {
        if entry.totals.failedCount > 0 {
            return "Action required!"
        } else if entry.totals.warningCount > 0 {
            return "Check metrics"
        } else if entry.totals.installationCount == 0 {
            return "Configure app"
        } else {
            return "All health checks passed"
        }
    }

    private func metricLabel(value: String, symbol: String, tooltip: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    var entry: ScrutinyMonitorWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            leftPanel
            Divider()
            rightPanel
        }
        .padding(2)
    }

    @ViewBuilder
    private var leftPanel: some View {
        // Left Panel (Overall Summary)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                statusIcon
                Text(statusTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text(statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                metricRow(title: "Installations", value: "\(entry.totals.installationCount)", symbol: "server.rack")
                metricRow(title: "Drives", value: "\(entry.totals.driveCount)", symbol: "externaldrive")
                if let avgTemp = entry.averageTemperature {
                    metricRow(title: "Avg Temp", value: "\(avgTemp)°C", symbol: "thermometer.medium")
                }
            }

            Spacer()

            HStack {
                Text(lastUpdatedText)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                // Sleek interactive Refresh pill-button
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(6)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 120)
    }

    @ViewBuilder
    private var rightPanel: some View {
        // Right Panel (Compact list of 3 worst drives or warning drives)
        VStack(alignment: .leading, spacing: 6) {
            Text("Drive Health")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            let list = entry.sortedDrives.prefix(3)
            if list.isEmpty {
                Spacer()
                Text("No monitored drives found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(list, id: \.id) { driveInfo in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(entry.statusColor(for: driveInfo.drive.status))
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(driveInfo.drive.name)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            Text(driveInfo.drive.model)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let temp = driveInfo.drive.temperature {
                            Text("\(temp)°C")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(entry.tempColor(for: temp))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if entry.totals.failedCount > 0 {
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(.red)
        } else if entry.totals.warningCount > 0 {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        } else if entry.totals.installationCount == 0 {
            Image(systemName: "tray")
                .foregroundColor(.secondary)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }

    private var statusTitle: String {
        if entry.totals.failedCount > 0 {
            return "Alert"
        } else if entry.totals.warningCount > 0 {
            return "Warning"
        } else if entry.totals.installationCount == 0 {
            return "Offline"
        } else {
            return "Healthy"
        }
    }

    private var statusSubtitle: String {
        if entry.totals.failedCount > 0 {
            return "\(entry.totals.failedCount) disk failures flagged."
        } else if entry.totals.warningCount > 0 {
            return "\(entry.totals.warningCount) warn-state drives."
        } else if entry.totals.installationCount == 0 {
            return "Configure servers in settings."
        } else {
            return "All drives are functioning normally."
        }
    }

    private var lastUpdatedText: String {
        if let maxDate = entry.maxLastRefreshDate {
            // ⚡ Bolt: Use a statically cached RelativeDateTimeFormatter to avoid expensive instantiation
            // overhead on every timeline rendering operation.
            return AppFormatters.relativeDate.localizedString(for: maxDate, relativeTo: Date())
        }
        return "Not synced"
    }

    private func metricRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    var entry: ScrutinyMonitorWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scrutiny Dashboard")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)

                    Text(summarySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lastUpdatedText)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("\(entry.totals.driveCount) Drives Total")
                            .font(.system(size: 8).weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    Button(intent: RefreshIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(6)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Detailed Drive Grid / List
            VStack(alignment: .leading, spacing: 5) {
                let list = entry.sortedDrives.prefix(6)
                if list.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No installations configured.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(list, id: \.id) { driveInfo in
                        HStack(spacing: 12) {
                            Image(systemName: driveInfo.drive.status.symbolName)
                                .font(.body)
                                .foregroundStyle(entry.statusColor(for: driveInfo.drive.status))
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(driveInfo.drive.name)
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(.primary)
                                Text("\(driveInfo.drive.model) • \(driveInfo.installation.name)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Temperature pill with custom color and gauge representation
                            if let temp = driveInfo.drive.temperature {
                                Text("\(temp)°C")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(entry.tempColor(for: temp))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2.5)
                                    .background(.regularMaterial, in: Capsule())
                            }

                            if let hours = driveInfo.drive.powerOnHours {
                                Text("\(hours) hrs")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.02))
                        )
                    }
                    Spacer()
                }
            }
        }
        .padding(2)
    }

    private var summarySubtitle: String {
        if entry.totals.failedCount > 0 {
            return "CRITICAL alert! Disk failure flagged."
        } else if entry.totals.warningCount > 0 {
            return "\(entry.totals.warningCount) drive(s) showing S.M.A.R.T. warnings."
        } else if entry.totals.installationCount == 0 {
            return "No connected servers."
        } else {
            return "All server drives are healthy."
        }
    }

    private var lastUpdatedText: String {
        if let maxDate = entry.maxLastRefreshDate {
            // ⚡ Bolt: Use a statically cached RelativeDateTimeFormatter to avoid expensive instantiation
            // overhead on every timeline rendering operation.
            return AppFormatters.relativeDate.localizedString(for: maxDate, relativeTo: Date())
        }
        return "Never synced"
    }
}
