//
//  ErrorPanel.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import SwiftUI

public struct ErrorPanel: View {
    var message: String

    public var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: \(message)")
    }
}
