//
//  HelpRow.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import SwiftUI

public struct HelpRow: View {
    var title: String
    var text: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
