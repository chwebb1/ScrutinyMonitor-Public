import XCTest
@testable import ScrutinyMonitor

final class ScrutinyAuthDelegateTests: XCTestCase {
    func testStripsHeadersOnHostChange() {
        let delegate = ScrutinyAuthDelegate(expectedHost: "localhost", expectedScheme: "https", secureTokenData: SecureData(data: Data("secret-token".utf8)))

        var originalRequest = URLRequest(url: URL(string: "https://localhost")!)
        originalRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        originalRequest.setValue("secret-key", forHTTPHeaderField: "X-API-Key")

        let newRequest = URLRequest(url: URL(string: "https://evil.com")!)
        var redirectedRequest = originalRequest
        redirectedRequest.url = newRequest.url

        let response = HTTPURLResponse(url: originalRequest.url!, statusCode: 302, httpVersion: nil, headerFields: ["Location": "https://evil.com"])!

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: originalRequest)

        let expectation = XCTestExpectation(description: "Completion handler called")

        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirectedRequest) { finalRequest in
            XCTAssertNotNil(finalRequest)
            XCTAssertNil(finalRequest?.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(finalRequest?.value(forHTTPHeaderField: "X-API-Key"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStripsHeadersOnSchemeDowngrade() {
        let delegate = ScrutinyAuthDelegate(expectedHost: "localhost", expectedScheme: "https", secureTokenData: SecureData(data: Data("secret-token".utf8)))

        var originalRequest = URLRequest(url: URL(string: "https://localhost")!)
        originalRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        let newRequest = URLRequest(url: URL(string: "http://localhost")!)
        var redirectedRequest = originalRequest
        redirectedRequest.url = newRequest.url

        let response = HTTPURLResponse(url: originalRequest.url!, statusCode: 302, httpVersion: nil, headerFields: ["Location": "http://localhost"])!

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: originalRequest)

        let expectation = XCTestExpectation(description: "Completion handler called")

        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirectedRequest) { finalRequest in
            XCTAssertNotNil(finalRequest)
            XCTAssertNil(finalRequest?.value(forHTTPHeaderField: "Authorization"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPreservesHeadersOnSafeRedirect() {
        let delegate = ScrutinyAuthDelegate(expectedHost: "localhost", expectedScheme: "https", secureTokenData: SecureData(data: Data("secret-token".utf8)))

        var originalRequest = URLRequest(url: URL(string: "https://localhost/api")!)
        originalRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        let newRequest = URLRequest(url: URL(string: "https://localhost/new-api")!)
        var redirectedRequest = originalRequest
        redirectedRequest.url = newRequest.url

        let response = HTTPURLResponse(url: originalRequest.url!, statusCode: 302, httpVersion: nil, headerFields: ["Location": "https://localhost/new-api"])!

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: originalRequest)

        let expectation = XCTestExpectation(description: "Completion handler called")

        delegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirectedRequest) { finalRequest in
            XCTAssertNotNil(finalRequest)
            XCTAssertEqual(finalRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}

private final class MockAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

final class WebDAVAuthDelegateTests: XCTestCase {
    func testPerformsDefaultHandlingForServerTrustChallenge() {
        let delegate = makeDelegate()
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust)

        let expectation = XCTestExpectation(description: "Completion handler called")
        delegate.urlSession(URLSession(configuration: .default), task: makeTask(), didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformsDefaultHandlingForUnsupportedAuthenticationMethod() {
        let delegate = makeDelegate()
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)

        let expectation = XCTestExpectation(description: "Completion handler called")
        delegate.urlSession(URLSession(configuration: .default), task: makeTask(), didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testCancelsRepeatedAuthenticationFailures() {
        let delegate = makeDelegate()
        let challenge = makeChallenge(previousFailureCount: 1)

        let expectation = XCTestExpectation(description: "Completion handler called")
        delegate.urlSession(URLSession(configuration: .default), task: makeTask(), didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testUsesCredentialForExpectedSecureHost() {
        let delegate = makeDelegate()
        let challenge = makeChallenge()

        let expectation = XCTestExpectation(description: "Completion handler called")
        delegate.urlSession(URLSession(configuration: .default), task: makeTask(), didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .useCredential)
            XCTAssertNotNil(credential)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    private func makeDelegate() -> WebDAVAuthDelegate {
        WebDAVAuthDelegate(
            expectedHost: "localhost",
            expectedScheme: "https",
            secureUsernameData: SecureData(data: Data("user".utf8)),
            securePasswordData: SecureData(data: Data("password".utf8))
        )
    }

    private func makeTask() -> URLSessionTask {
        URLSession(configuration: .default).dataTask(with: URLRequest(url: URL(string: "https://localhost")!))
    }

    private func makeChallenge(
        host: String = "localhost",
        protocol scheme: String = NSURLProtectionSpaceHTTPS,
        authenticationMethod: String = NSURLAuthenticationMethodHTTPBasic,
        previousFailureCount: Int = 0
    ) -> URLAuthenticationChallenge {
        let protectionSpace = URLProtectionSpace(
            host: host,
            port: 443,
            protocol: scheme,
            realm: nil,
            authenticationMethod: authenticationMethod
        )
        return URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: previousFailureCount,
            failureResponse: nil,
            error: nil,
            sender: MockAuthenticationChallengeSender()
        )
    }
}
