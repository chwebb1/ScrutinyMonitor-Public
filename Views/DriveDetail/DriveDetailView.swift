import SwiftUI

struct DriveDetailView: View {
    var installation: ScrutinyInstallation
    var drive: DriveSnapshot
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: DriveDetail?
    @State private var errorMessage: String?
    @State private var isLoading = true

    @AppStorage("isHistoryChartExpanded") private var isHistoryChartExpanded = true
    @AppStorage("isAttributesExpanded") private var isAttributesExpanded = true

    var client: ScrutinyClient = .shared

    internal let inspection = Inspection<Self>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            content
        }
        .frame(minWidth: 820, idealWidth: 820, maxWidth: .infinity, minHeight: 560, idealHeight: 560, maxHeight: .infinity)
        .resizableSheet()
        .task(id: drive.id) {
            await load()
        }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text("\(drive.model) - \(drive.serial)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(drive.name), Model: \(drive.model), Serial: \(drive.serial)")

            Spacer()

            Button("Done") {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .help("Done (Return)")
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading SMART details...")
                .accessibilityLabel("Loading SMART details")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Could Not Load Drive Details", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await load() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            ScrollView {
                // ⚡ Bolt: Convert standard VStack to LazyVStack for potentially large dynamic dataset (SMART attributes)
                LazyVStack(alignment: .leading, spacing: 18) {
                    DriveSummaryGrid(drive: drive, detail: detail)
                    
                    if detail.history.count > 1 {
                        DisclosureGroup(isExpanded: $isHistoryChartExpanded) {
                            DriveHistoryChart(detail: detail)
                        } label: {
                            Text("Historical S.M.A.R.T. Metrics")
                                .font(.title3.weight(.semibold))
                        }
                    }

                    DisclosureGroup(isExpanded: $isAttributesExpanded) {
                        SmartAttributesTable(attributes: detail.attributes)
                    } label: {
                        Text("SMART Attributes")
                            .font(.title3.weight(.semibold))
                    }
                }
                .padding(20)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            detail = try await client.fetchDriveDetail(for: drive, installation: installation)
        } catch {
            errorMessage = error.secureDescription
        }

        isLoading = false
    }
}





