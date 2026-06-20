import XCTest
@testable import ScrutinyMonitor

final class FormattersTests: XCTestCase {

    func testAppendingScrutinyEndpoint_Basic() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_BaseHasTrailingSlash() {
        let baseURL = URL(string: "http://example.com/")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_EndpointHasLeadingSlash() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "/api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_BothHaveSlashes() {
        let baseURL = URL(string: "http://example.com/")!
        let endpoint = "/api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_BaseHasMultipleTrailingSlashes() {
        let baseURL = URL(string: "http://example.com///")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_PreservesQueryParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?query=1"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?query=1")
    }

    func testAppendingScrutinyEndpoint_BaseHasPort() {
        let baseURL = URL(string: "http://example.com:8080")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com:8080/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_BaseHasPath() {
        let baseURL = URL(string: "http://example.com/subpath")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/subpath/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_BaseHasPathWithTrailingSlash() {
        let baseURL = URL(string: "http://example.com/subpath/")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/subpath/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_EmptyEndpoint() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = ""
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com")
    }

    func testAppendingScrutinyEndpoint_EndpointHasMultipleLeadingSlashes() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "//api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_InvalidEndpoint() {
        // String with invalid characters (e.g. unencoded spaces or control characters) that fails URLComponents
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status 123"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status%20123")
    }

    func testAppendingScrutinyEndpoint_InvalidEndpointString2() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "http://[1::2::3]/" // Malformed IPv6 address causes URLComponents to fail on some OS, but parses as path '/' on others
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/")
    }

    func testAppendingScrutinyEndpoint_MultipleQueryParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?query=1&sort=desc"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?query=1&sort=desc")
    }
    
    func testAppendingScrutinyEndpoint_MultipleQueryParameters2() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?param1=value1&param2=value2"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?param1=value1&param2=value2")
    }

    func testAppendingScrutinyEndpoint_EncodedQueryParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?filter=a%26b"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?filter=a%26b")
    }

    func testAppendingScrutinyEndpoint_OnlyQueryParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "?query=1"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com?query=1")
    }

    func testAppendingScrutinyEndpoint_PreservesEncodedQueryParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?query=hello%26world"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?query=hello%26world")
    }

    func testAppendingScrutinyEndpoint_RootPath() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "/"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/")
    }

    func testAppendingScrutinyEndpoint_DoubleSlashInMiddle() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "/api//v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status")
    }

    func testAppendingScrutinyEndpoint_TrailingSlash() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "/api/v1/status/"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status/")
    }

    func testAppendingScrutinyEndpoint_BaseHasQueryParameters() {
        let baseURL = URL(string: "http://example.com?base=1")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?base=1")
    }

    func testAppendingScrutinyEndpoint_BothHaveQueryParametersMerges() {
        let baseURL = URL(string: "http://example.com?base=1")!
        let endpoint = "api/v1/status?endpoint=2"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?base=1&endpoint=2")
    }

    func testAppendingScrutinyEndpoint_EndpointHasFragment() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status#fragment"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status#fragment")
    }

    func testAppendingScrutinyEndpoint_BaseHasFragment() {
        let baseURL = URL(string: "http://example.com#basefragment")!
        let endpoint = "api/v1/status"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status#basefragment")
    }

    func testAppendingScrutinyEndpoint_BothHaveQueryParametersAndFragments() {
        let baseURL = URL(string: "http://example.com?base=1#basefragment")!
        let endpoint = "api/v1/status?endpoint=2#fragment"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?base=1&endpoint=2#fragment")
    }

    func testAppendingScrutinyEndpoint_OverridingQueryParameters() {
        let baseURL = URL(string: "http://example.com?param=1")!
        let endpoint = "api/v1/status?param=2"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?param=2")
    }

    func testAppendingScrutinyEndpoint_OverridingPercentEncodedQueryParameters() {
        let baseURL = URL(string: "http://example.com?filter%3Astatus=old&sort=asc")!
        let endpoint = "api/v1/status?filter%3astatus=new"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?sort=asc&filter%3astatus=new")
    }

    func testAppendingScrutinyEndpoint_EndpointHasDuplicateParameters() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status?tag=swift&tag=ios"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?tag=swift&tag=ios")
    }

    func testAppendingScrutinyEndpoint_BaseHasDuplicateParametersOverride() {
        let baseURL = URL(string: "http://example.com?tag=swift&tag=ios")!
        let endpoint = "api/v1/status?tag=kotlin"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?tag=kotlin")
    }

    func testAppendingScrutinyEndpoint_QueryOnlyEndpoint() {
        let baseURL = URL(string: "http://example.com/api/v1/status")!
        let endpoint = "?key=value"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?key=value")
    }

    func testAppendingScrutinyEndpoint_FragmentOnlyEndpoint() {
        let baseURL = URL(string: "http://example.com/api/v1/status")!
        let endpoint = "#section"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status#section")
    }

    func testAppendingScrutinyEndpoint_MultiValueQueryParametersBaseAndEndpoint() {
        let baseURL = URL(string: "http://example.com/api/v1/status?tag=1&tag=2")!
        let endpoint = "?tag=3&tag=4"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?tag=3&tag=4")
    }

    func testAppendingScrutinyEndpoint_PercentEncodedPathSeparator() {
        let baseURL = URL(string: "http://example.com")!
        let endpoint = "api/v1/status/hello%2Fworld"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status/hello%2Fworld")
    }

    func testAppendingScrutinyEndpoint_PathTraversalAttempt() {
        let baseURL = URL(string: "http://example.com/api/v1/status/")!
        let endpoint = "../../admin"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/admin")
    }

    func testAppendingScrutinyEndpoint_QueryOnlyWhitespace() {
        let baseURL = URL(string: "http://example.com/api/v1/status")!
        let endpoint = "?key=  "
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?key=%20%20")
    }

    func testAppendingScrutinyEndpoint_EmptyQueryPreservesBase() {
        let baseURL = URL(string: "http://example.com/api/v1/status?base=1")!
        let endpoint = "?"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status?base=1")
    }

    func testAppendingScrutinyEndpoint_EmptySlashEndpoint() {
        let baseURL = URL(string: "http://example.com/api/v1/status")!
        let endpoint = "/"
        let result = baseURL.appendingScrutinyEndpoint(endpoint)
        XCTAssertEqual(result.absoluteString, "http://example.com/api/v1/status/")
    }

    func testFormattedBytes_Nil() {
        let value: Int64? = nil
        XCTAssertEqual(value.formattedBytes, "Unknown")
    }

    func testFormattedBytes_Valid() {
        let bytes: Int64 = 1_500_000_000
        let value: Int64? = bytes
        let expected = AppFormatters.byteCount.string(fromByteCount: bytes)
        XCTAssertEqual(value.formattedBytes, expected)
    }

    func testFormattedBytes_Zero() {
        let bytes: Int64 = 0
        let value: Int64? = bytes
        let expected = AppFormatters.byteCount.string(fromByteCount: bytes)
        XCTAssertEqual(value.formattedBytes, expected)
}
    func testOptionalIntTemperatureText_WithValue() {
        let temp: Int? = 35
        XCTAssertEqual(temp.temperatureText, "35 C")
    }

    func testOptionalIntTemperatureText_WithNil() {
        let temp: Int? = nil
        XCTAssertEqual(temp.temperatureText, "-")
    }

    func testOptionalIntHoursText_WithValue() {
        let hours: Int? = 100
        XCTAssertEqual(hours.hoursText, "100 h")
    }

    func testOptionalIntHoursText_WithNil() {
        let hours: Int? = nil
        XCTAssertEqual(hours.hoursText, "-")
    }

    func testIntFormattedTemperature() {
        let temp: Int = 35
        XCTAssertEqual(temp.formattedTemperature, "35 C")
    }

    func testIntFormattedHours() {
        let hours: Int = 100
        XCTAssertEqual(hours.formattedHours, "100 h")
    }
}
