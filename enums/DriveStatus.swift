//
//  DriveStatus.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import Foundation

public enum DriveStatus: String, Codable {
    case passed
    case warning
    case failed
    case unknown

    public init(statusCode: Int?) {
        guard let statusCode else {
            self = .unknown
            return
        }

        switch statusCode {
        case 0:
            self = .passed
        case 1:
            self = .warning
        default:
            self = .failed
        }
    }

    public var label: String {
        switch self {
        case .passed: "Passed"
        case .warning: "Warning"
        case .failed: "Failed"
        case .unknown: "Unknown"
        }
    }

    public var sortRank: Int {
        switch self {
        case .failed:
            0
        case .warning:
            1
        case .unknown:
            2
        case .passed:
            3
        }
    }
}
