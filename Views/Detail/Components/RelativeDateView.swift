//
//  RelativeDateView.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI
public struct RelativeDateView: View {
    var lastRefreshDate: Date

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 10)) { timelineContext in
            // ⚡ Bolt: Use TimelineView with a 10s period to avoid the aggressive 1-second
            // re-renders of the previous Timer publisher, saving main-thread cycles.
            Text(statusText(for: lastRefreshDate, relativeTo: timelineContext.date))
                .foregroundStyle(.secondary)
        }
    }

    private func statusText(for date: Date, relativeTo referenceDate: Date) -> String {
        let diff = abs(referenceDate.timeIntervalSince(date))
        if diff < 10 {
            return "Updated just now"
        }
        return "Updated approximately \(AppFormatters.relativeDate.localizedString(for: date, relativeTo: referenceDate))"
    }
}
