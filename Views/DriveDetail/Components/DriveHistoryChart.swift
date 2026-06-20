import SwiftUI
import Charts

enum ChartMetric: Hashable, Identifiable {
    case temperature
    case powerOnHours
    case powerCycleCount
    case attribute(id: String, name: String)
    
    var id: String {
        switch self {
        case .temperature: return "temp"
        case .powerOnHours: return "poh"
        case .powerCycleCount: return "pcc"
        case .attribute(let id, _): return "attr-\(id)"
        }
    }
    
    var title: String {
        switch self {
        case .temperature: return "Temperature"
        case .powerOnHours: return "Power On Hours"
        case .powerCycleCount: return "Power Cycle Count"
        case .attribute(_, let name): return name
        }
    }
    
    var gradient: Gradient {
        switch self {
        case .temperature: return Gradient(colors: [.orange, .red])
        case .powerOnHours: return Gradient(colors: [.cyan, .blue])
        case .powerCycleCount: return Gradient(colors: [.green, .mint])
        case .attribute: return Gradient(colors: [.purple, .indigo])
        }
    }
    
    func extractValue(from result: SmartResult) -> Int? {
        switch self {
        case .temperature: return result.temperature?.value
        case .powerOnHours: return result.powerOnHours?.value
        case .powerCycleCount: return result.powerCycleCount?.value
        case .attribute(let id, _):
            return result.attributes[id]?.transformedValue ?? result.attributes[id]?.value
        }
    }
}

struct DriveHistoryChart: View {
    let detail: DriveDetail
    let availableMetrics: [ChartMetric]
    
    @AppStorage("selectedDriveChartMetricId") private var selectedMetricId: String = "temp"
    
    init(detail: DriveDetail) {
        self.detail = detail

        // ⚡ Bolt: Pre-calculate availableMetrics once in init to avoid redundant
        // array allocations and O(M) loops during SwiftUI render passes.
        var metrics: [ChartMetric] = [.temperature, .powerOnHours, .powerCycleCount]
        for attr in detail.attributes {
            metrics.append(.attribute(id: attr.id, name: attr.name))
        }
        self.availableMetrics = metrics
    }
    
    var currentMetric: ChartMetric {
        availableMetrics.first { $0.id == selectedMetricId } ?? .temperature
    }
    
    private var selectedMetricBinding: Binding<ChartMetric> {
        Binding(
            get: { currentMetric },
            set: { selectedMetricId = $0.id }
        )
    }
    
    var yDomain: ClosedRange<Int> {
        // ⚡ Bolt: Cache currentMetric locally to prevent evaluating the O(M) .first(where:)
        // search inside the loop below. Also find min/max in a single imperative loop
        // instead of allocating an intermediate array via compactMap.
        let metric = currentMetric
        var minVal: Int?
        var maxVal: Int?

        for result in detail.history {
            if let val = metric.extractValue(from: result) {
                minVal = min(minVal ?? val, val)
                maxVal = max(maxVal ?? val, val)
            }
        }

        guard let minVal, let maxVal else {
            return 0...10
        }
        
        // Calculate padding based on whether values are equal
        let padding: Int
        if minVal == maxVal {
            if minVal == 0 { return 0...5 }
            // Use saturated magnitude to avoid abs(Int.min) overflow crash
            let magnitude = minVal == Int.min ? Int.max : abs(minVal)
            padding = max(1, magnitude / 10)
        } else {
            let diff = subtractingWithSaturation(maxVal, minVal)
            padding = max(1, diff / 10)
        }

        // Calculate bounds with padding
        let lowerBoundValue = subtractingWithSaturation(minVal, padding)
        let lowerBound = minVal >= 0 ? max(0, lowerBoundValue) : lowerBoundValue
        let upperBound = addingWithSaturation(maxVal, padding)
        return lowerBound...upperBound
    }
    
    var body: some View {
        // ⚡ Bolt: Cache currentMetric locally to avoid re-evaluating the property
        // for every item in the Chart's ForEach loop, dropping complexity from O(M*N) to O(M+N).
        let metric = currentMetric

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(metric.title + " History")
                    .font(.headline)

                Spacer()

                Picker("Metric", selection: selectedMetricBinding) {
                    ForEach(availableMetrics) { m in
                        Text(m.title).tag(m)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Metric")
                .frame(maxWidth: 250)
            }

            Chart {
                // ⚡ Bolt: Use explicit, stable identity for ForEach instead of \.self.
                // Hashing the entire SmartResult struct repeatedly during Chart layout
                // creates unnecessary memory allocations and blocks the main thread.
                ForEach(detail.history, id: \.date) { result in
                    if let date = result.parsedDate, let val = metric.extractValue(from: result) {
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Value", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.gradient)

                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Value", val)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.gradient.opacity(0.1))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(minHeight: 200)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    /// Performs addition or subtraction with overflow saturation
    /// - Parameters:
    ///   - value: The base value
    ///   - delta: The amount to add (positive) or subtract (negative)
    ///   - isAdding: If true, performs addition; if false, performs subtraction
    /// - Returns: The result, saturated to Int.max or Int.min on overflow
    private func withSaturation(_ value: Int, _ delta: Int, _ isAdding: Bool) -> Int {
        let result = isAdding
            ? value.addingReportingOverflow(delta)
            : value.subtractingReportingOverflow(delta)

        if result.overflow {
            // On overflow: saturate to max if direction matches delta sign, else min
            return isAdding == (delta >= 0) ? Int.max : Int.min
        }
        return result.partialValue
    }

    private func addingWithSaturation(_ value: Int, _ increment: Int) -> Int {
        withSaturation(value, increment, true)
    }

    private func subtractingWithSaturation(_ value: Int, _ decrement: Int) -> Int {
        withSaturation(value, decrement, false)
    }
}
