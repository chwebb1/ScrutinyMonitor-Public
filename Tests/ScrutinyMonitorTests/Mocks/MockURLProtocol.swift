import Foundation

class MockURLProtocol: URLProtocol {
    typealias RequestHandler = (URLRequest) throws -> (URLResponse, Data)
    typealias AsyncRequestHandler = (URLRequest) async throws -> (URLResponse, Data)

    private static let lock = NSLock()
    private static var storedRequestHandler: RequestHandler?
    private static var storedAsyncRequestHandler: AsyncRequestHandler?
    private var loadingTask: Task<Void, Never>?

    static var requestHandler: RequestHandler? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedRequestHandler
        }
        set {
            lock.lock()
            storedRequestHandler = newValue
            lock.unlock()
        }
    }

    static var asyncRequestHandler: AsyncRequestHandler? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedAsyncRequestHandler
        }
        set {
            lock.lock()
            storedAsyncRequestHandler = newValue
            lock.unlock()
        }
    }

    static func reset() {
        requestHandler = nil
        asyncRequestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let asyncHandler = Self.asyncRequestHandler {
            loadingTask = Task { [request, weak self] in
                guard let self else { return }

                do {
                    let (response, data) = try await asyncHandler(request)
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    self.client?.urlProtocol(self, didLoad: data)
                    self.client?.urlProtocolDidFinishLoading(self)
                } catch {
                    self.client?.urlProtocol(self, didFailWithError: error)
                }
            }
            return
        }

        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}
