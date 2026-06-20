import Foundation

enum AppFormatters {
    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static let relativeDateFull: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        return formatter
    }()
}

extension URL {
    func appendingScrutinyEndpoint(_ endpoint: String) -> URL {
        var trimmedEndpoint = endpoint[...]
        // Strip leading slashes to ensure the endpoint is always treated as a relative path
        // to be appended to the base URL, rather than an absolute path that could overwrite it.
        while trimmedEndpoint.hasPrefix("/") {
            trimmedEndpoint.removeFirst()
        }

        guard let endpointComponents = URLComponents(string: String(trimmedEndpoint)) else { return self }

        guard var baseComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else { return self }

        // 1. Append path components safely using percentEncodedPath
        if !endpointComponents.percentEncodedPath.isEmpty {
            let baseSegments = baseComponents.percentEncodedPath.split(separator: "/")
            let endpointSegments = endpointComponents.percentEncodedPath.split(separator: "/")
            var resolvedSegments = baseSegments

            for segment in endpointSegments {
                if segment == "." { continue }
                if segment == ".." {
                    if !resolvedSegments.isEmpty { resolvedSegments.removeLast() }
                    continue
                }
                resolvedSegments.append(segment)
            }

            let filteredSegments = resolvedSegments.filter { !$0.isEmpty }
            var path = filteredSegments.isEmpty ? "/" : "/" + filteredSegments.joined(separator: "/")

            if endpointComponents.percentEncodedPath.hasSuffix("/") {
                if !path.hasSuffix("/") { path += "/" }
            } else if endpointSegments.isEmpty && baseComponents.percentEncodedPath.hasSuffix("/") {
                if !path.hasSuffix("/") { path += "/" }
            }

            baseComponents.percentEncodedPath = path
        } else if endpoint.hasSuffix("/") {
            // Handle edge case where endpoint was explicitly "/" but stripped earlier
            if !baseComponents.percentEncodedPath.hasSuffix("/") {
                baseComponents.percentEncodedPath += "/"
            }
        }

        // 2. Merge query items
        // Design Decision: Endpoint query parameters intentionally override base parameters with the same key
        // rather than appending duplicates, while completely preserving non-matching base parameters.
        if let endpointQueryItems = endpointComponents.percentEncodedQueryItems, !endpointQueryItems.isEmpty {
            var mergedQueryItems = baseComponents.percentEncodedQueryItems ?? []
            // Decode endpoint keys once for efficiency - avoids repeated decoding in removeAll closure
            let endpointKeys = Set(endpointQueryItems.map { $0.name.removingPercentEncoding ?? $0.name })

            // Only keep base items whose keys don't exist in endpoint
            mergedQueryItems.removeAll { item in
                let decodedName = item.name.removingPercentEncoding ?? item.name
                return endpointKeys.contains(decodedName)
            }
            // Append all new query items
            mergedQueryItems.append(contentsOf: endpointQueryItems)

            baseComponents.percentEncodedQueryItems = mergedQueryItems
        }

        // 3. Resolve fragment (endpoint fragment takes priority over base fragment)
        if let endpointFragment = endpointComponents.percentEncodedFragment {
            baseComponents.percentEncodedFragment = endpointFragment
        }

        return baseComponents.url ?? self
    }
}

extension Optional where Wrapped == Int64 {
    var formattedBytes: String {
        guard let self else { return "Unknown" }
        return AppFormatters.byteCount.string(fromByteCount: self)
    }
}

extension Optional where Wrapped == Int {
    var temperatureText: String {
        guard let self else { return "-" }
        return "\(self) C"
    }

    var hoursText: String {
        guard let self else { return "-" }
        return "\(self) h"
    }
}

extension Int {
    var formattedTemperature: String {
        "\(self) C"
    }

    var formattedHours: String {
        "\(self) h"
    }
}
