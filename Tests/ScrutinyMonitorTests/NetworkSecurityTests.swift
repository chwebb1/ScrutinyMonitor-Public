import XCTest
@testable import ScrutinyMonitor

final class NetworkSecurityTests: XCTestCase {
    var tempResolvConfURL: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempResolvConfURL = tempDir.appendingPathComponent(UUID().uuidString + "-resolv.conf")
        NetworkSecurity.resolvConfPath = tempResolvConfURL.path
        NetworkSecurity.resetResolvDomainCacheForTesting()
        NetworkSecurity.readTimeout = 2.0
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempResolvConfURL.path) {
            try FileManager.default.removeItem(at: tempResolvConfURL)
        }
        NetworkSecurity.resolvConfPath = "/etc/resolv.conf" // Reset to default
        NetworkSecurity.resetResolvDomainCacheForTesting()
        NetworkSecurity.readTimeout = 0.1
        try super.tearDownWithError()
    }

    func writeResolvConf(_ content: String) throws {
        try content.write(to: tempResolvConfURL, atomically: true, encoding: .utf8)
    }

    func testResolvConfSearchHappyPath() throws {
        try writeResolvConf("""
        search local.domain corp.domain
        nameserver 8.8.8.8
        """)

        XCTAssertTrue(NetworkSecurity.isLocalHost("test.local.domain"))
        XCTAssertTrue(NetworkSecurity.isLocalHost("test.corp.domain"))
        XCTAssertTrue(NetworkSecurity.isLocalHost("corp.domain"))
        XCTAssertFalse(NetworkSecurity.isLocalHost("external.com"))
    }

    func testResolvConfDomainHappyPath() throws {
        try writeResolvConf("""
        domain myhome.net
        nameserver 8.8.8.8
        """)

        XCTAssertTrue(NetworkSecurity.isLocalHost("server.myhome.net"))
        XCTAssertTrue(NetworkSecurity.isLocalHost("myhome.net"))
        XCTAssertFalse(NetworkSecurity.isLocalHost("other.net"))
    }

    func testResolvConfSearchEdgeCasesMaliciousPrefix() throws {
        try writeResolvConf("""
        searchdomain bypass.com
        nameserver 8.8.8.8
        """)

        XCTAssertFalse(NetworkSecurity.isLocalHost("test.bypass.com"), "searchdomain should not be parsed as a valid search directive")
    }

    func testResolvConfDomainEdgeCasesMaliciousPrefix() throws {
        try writeResolvConf("""
        domainxyz bypass.com
        nameserver 8.8.8.8
        """)

        XCTAssertFalse(NetworkSecurity.isLocalHost("test.bypass.com"), "domainxyz should not be parsed as a valid domain directive")
    }

    func testResolvConfWhitespaceHandling() throws {
        try writeResolvConf("search\tcorp.domain  other.domain\tanother.domain")
        
        XCTAssertTrue(NetworkSecurity.isLocalHost("test.corp.domain"))
        XCTAssertTrue(NetworkSecurity.isLocalHost("test.other.domain"))
        XCTAssertTrue(NetworkSecurity.isLocalHost("test.another.domain"))
    }
    
    func testIsLocalHost_IPv4_Local() {
        XCTAssertTrue(NetworkSecurity.isLocalHost("10.0.0.1"), "10.x.x.x should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("172.16.0.1"), "172.16.x.x should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("172.31.255.255"), "172.31.x.x should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("192.168.1.1"), "192.168.x.x should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("127.0.0.1"), "127.x.x.x should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("169.254.0.1"), "169.254.x.x should be local")
    }

    func testIsLocalHost_IPv4_NonLocal() {
        XCTAssertFalse(NetworkSecurity.isLocalHost("8.8.8.8"), "8.8.8.8 should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("172.32.0.1"), "172.32.x.x should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("192.169.1.1"), "192.169.x.x should not be local")
    }

    func testIsLocalHost_IPv6_Local() {
        XCTAssertTrue(NetworkSecurity.isLocalHost("::1"), "Loopback should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("fc00::1"), "Unique Local Address should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("fd00::1"), "Unique Local Address should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("fe80::1"), "Link-local should be local")

        // Bracketed notation
        XCTAssertTrue(NetworkSecurity.isLocalHost("[::1]"), "Bracketed loopback should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("[fe80::1]"), "Bracketed link-local should be local")
    }

    func testIsLocalHost_IPv6_NonLocal() {
        XCTAssertFalse(NetworkSecurity.isLocalHost("2001:4860:4860::8888"), "Google DNS IPv6 should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("[2001:4860:4860::8888]"), "Bracketed Google DNS IPv6 should not be local")
    }

    func testIsLocalHost_IPv6_EdgeCases() {
        XCTAssertTrue(NetworkSecurity.isLocalHost("::"), "Unspecified address should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("::ffff:127.0.0.1"), "IPv4-mapped loopback should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("::ffff:10.0.0.1"), "IPv4-mapped local should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("::127.0.0.1"), "IPv4-compatible loopback should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("[::ffff:127.0.0.1]"), "Bracketed IPv4-mapped loopback should be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("::ffff:8.8.8.8"), "IPv4-mapped public should not be local")
    }

    func testIsLocalHost_Hostnames() {
        XCTAssertTrue(NetworkSecurity.isLocalHost("localhost"), "localhost should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("my-nas.local"), ".local suffix should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("unqualified"), "unqualified hostname should be local")

        XCTAssertFalse(NetworkSecurity.isLocalHost("google.com"), "Public domain should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("example.org"), "Public domain should not be local")
    }

    func testIsLocalHost_NumericBypass() {
        XCTAssertFalse(NetworkSecurity.isLocalHost("134744072"), "Integer representation of 8.8.8.8 should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("0x08080808"), "Hex representation of 8.8.8.8 should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("0X08080808"), "Hex representation (upper) should not be local")
        XCTAssertFalse(NetworkSecurity.isLocalHost("4294967296"), "Integer overflow string should not be local")
	}

	func testIsLocalHost_DotlessIPRepresentations() {
        XCTAssertFalse(NetworkSecurity.isLocalHost("134744072"), "Integer representation of 8.8.8.8 should safely evaluate as public")
        XCTAssertFalse(NetworkSecurity.isLocalHost("0x08080808"), "Hex representation of 8.8.8.8 should safely evaluate as public")
        XCTAssertFalse(NetworkSecurity.isLocalHost("012345678901234567890"), "Unparsed numeric-looking strings should not fall back to the dotless local-hostname rule")
        XCTAssertFalse(NetworkSecurity.isLocalHost("0x999999999999999999999999"), "Unparsed hex-looking strings should not fall back to the dotless local-hostname rule")

        // Parsed octal loopback forms should still be blocked as local.
        XCTAssertTrue(NetworkSecurity.isLocalHost("017700000001"), "Octal loopback strings should be treated as local")

        // 0 / 0.0.0.0 routes to localhost and must be blocked.
        XCTAssertTrue(NetworkSecurity.isLocalHost("0"), "0 routing to localhost should be treated as local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("0.0.0.0"), "0.0.0.0 routing to localhost should be treated as local")
    }

    func testIsLocalHost_ResolvConf_Search() {
        let tempDir = FileManager.default.temporaryDirectory
        let resolvConfPath = tempDir.appendingPathComponent(UUID().uuidString + "-resolv-search.conf").path
        let resolvData = """
        # Comment
        search corp.example.com internal.net
        nameserver 8.8.8.8
        """

        do {
            try resolvData.write(toFile: resolvConfPath, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to write mock resolv.conf")
            return
        }
        defer { try? FileManager.default.removeItem(atPath: resolvConfPath) }

        XCTAssertTrue(NetworkSecurity.isLocalHost("server.corp.example.com", resolvConfPath: resolvConfPath), "Suffix match for search domain should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("corp.example.com", resolvConfPath: resolvConfPath), "Exact match for search domain should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("api.internal.net", resolvConfPath: resolvConfPath), "Suffix match for second search domain should be local")

        XCTAssertFalse(NetworkSecurity.isLocalHost("server.other.com", resolvConfPath: resolvConfPath), "Non-matching domain should not be local")
    }

    func testIsLocalHost_ResolvConf_Domain() {
        let tempDir = FileManager.default.temporaryDirectory
        let resolvConfPath = tempDir.appendingPathComponent(UUID().uuidString + "-resolv-domain.conf").path
        let resolvData = """
        domain mycompany.internal
        """

        do {
            try resolvData.write(toFile: resolvConfPath, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to write mock resolv.conf")
            return
        }
        defer { try? FileManager.default.removeItem(atPath: resolvConfPath) }

        XCTAssertTrue(NetworkSecurity.isLocalHost("db.mycompany.internal", resolvConfPath: resolvConfPath), "Suffix match for domain should be local")
        XCTAssertTrue(NetworkSecurity.isLocalHost("mycompany.internal", resolvConfPath: resolvConfPath), "Exact match for domain should be local")

        XCTAssertFalse(NetworkSecurity.isLocalHost("db.othercompany.internal", resolvConfPath: resolvConfPath), "Non-matching domain should not be local")
    }

    func testResolvConfMissingFile() {
        let tempDir = FileManager.default.temporaryDirectory
        let missingPath = tempDir.appendingPathComponent(UUID().uuidString + "-missing.conf").path

        // A non-existent resolv.conf should silently fail to load and return no search domains,
        // so a domain that isn't inherently local should safely evaluate to false.
        XCTAssertFalse(NetworkSecurity.isLocalHost("external.com", resolvConfPath: missingPath), "A missing resolv.conf should fail gracefully and not match external domains")
    }
}
