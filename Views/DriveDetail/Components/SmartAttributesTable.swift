//
//  SmartAttributesTable.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import SwiftUI

public struct SmartAttributesTable: View {
    var attributes: [SmartAttributeRow]

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if attributes.isEmpty {
                ContentUnavailableView(
                    "No SMART Attributes",
                    systemImage: "tablecells",
                    description: Text("Scrutiny did not return attribute history for this drive.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Attribute").bold()
                        Text("Value").bold()
                        Text("Worst").bold()
                        Text("Threshold").bold()
                        Text("Raw").bold()
                        Text("Status").bold()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    ForEach(attributes) { row in
                        GridRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .lineLimit(1)

                                if row.shouldShowIdentifier {
                                    Text(row.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.shouldShowIdentifier ? "\(row.name), ID: \(row.id)" : row.name)
                            
                            Text(row.valueText)
                                .gridColumnAlignment(.trailing)
                            
                            Text(row.worstText)
                                .gridColumnAlignment(.trailing)
                            
                            Text(row.thresholdText)
                                .gridColumnAlignment(.trailing)
                            
                            Text(row.rawText)
                                .lineLimit(1)
                            
                            Text(row.statusText)
                                .foregroundStyle(row.severity.color)
                                .lineLimit(1)
                                .help(row.statusDetailText)
                        }
                        Divider()
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
