import SwiftUI


struct DriveListingTable: View {
    var title: String
    var columnTitles: [String]
    var modelColumnIndex: Int
    var rows: [DriveListingRow]
    var onOpenRow: (DriveListingRow) -> Void

    private let statusColumnIndex: Int?

    init(title: String, columnTitles: [String], modelColumnIndex: Int, rows: [DriveListingRow], onOpenRow: @escaping (DriveListingRow) -> Void) {
        self.title = title
        self.columnTitles = columnTitles
        self.modelColumnIndex = modelColumnIndex
        self.rows = rows
        self.onOpenRow = onOpenRow
        self.statusColumnIndex = columnTitles.firstIndex(of: "Status")
    }

    private var columns: [GridItem] {
        var items = [GridItem]()
        items.reserveCapacity(columnTitles.count)

        // ⚡ Bolt: Transpose rows column-by-column rather than interleaved.
        // Modifying inner arrays inside a 2D array within a tight nested loop
        // triggers continuous value-type copy-on-write and exclusivity checks.
        var transposedValues = [[String]]()
        transposedValues.reserveCapacity(columnTitles.count)
        for index in 0..<columnTitles.count {
            var columnValues = [String]()
            columnValues.reserveCapacity(rows.count)
            columnValues.append(contentsOf: rows.lazy.compactMap { row in
                index < row.values.count ? row.values[index] : nil
            })
            transposedValues.append(columnValues)
        }

        for (index, title) in columnTitles.enumerated() {
            if index == modelColumnIndex {
                items.append(DriveGridColumnSizing.modelColumn())
            } else if title.isEmpty {
                items.append(DriveGridColumnSizing.buttonColumn())
            } else {
                items.append(
                    DriveGridColumnSizing.measuredTextColumn(
                        title: title,
                        values: transposedValues[index]
                    )
                )
            }
        }
        return items
    }

    var body: some View {
        // ⚡ Bolt: statusColumnIndex is now pre-calculated once during init rather than within the view body.
        // This drops evaluation complexity during frequent SwiftUI render cycles and reduces main-thread CPU overhead.
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))

                Spacer()

                Text("Double-click a row or use the info button for SMART details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Drives Found",
                        systemImage: "externaldrive.badge.questionmark",
                        description: Text("Scrutiny did not report any drives for this installation.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                        ForEach(Array(columnTitles.enumerated()), id: \.offset) { _, title in
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.vertical, 8)
                        }

                        ForEach(rows) { row in
                            ForEach(row.cells) { cell in
                                DriveListingCellText(cell.value, row: row, onOpenRow: onOpenRow)
                                    .foregroundStyle(cell.index == statusColumnIndex ? row.drive.status.color : .primary)
                            }

                            Button {
                                onOpenRow(row)
                            } label: {
                                Label("Show Details", systemImage: "info.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Show SMART details for \(row.drive.name)")
                            .help("Show SMART details for \(row.drive.name)")
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
    }
}


private struct DriveListingCellText: View {
    var text: String
    var row: DriveListingRow
    var onOpenRow: (DriveListingRow) -> Void
    @State private var isHovered = false

    init(_ text: String, row: DriveListingRow, onOpenRow: @escaping (DriveListingRow) -> Void) {
        self.text = text
        self.row = row
        self.onOpenRow = onOpenRow
    }

    var body: some View {
        Text(text)
            .lineLimit(1)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture(count: 2) {
                onOpenRow(row)
            }
            .help("Double-click for details")
    }
}
