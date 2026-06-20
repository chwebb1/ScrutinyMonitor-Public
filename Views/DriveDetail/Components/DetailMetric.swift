//
//  DetailMetric.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI

public struct DetailMetric: View {
    var title: String
    var value: String
    var symbol: String
    var valueColor: Color? = nil

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .help("\(title): \(value)")
        .padding(12)
        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
