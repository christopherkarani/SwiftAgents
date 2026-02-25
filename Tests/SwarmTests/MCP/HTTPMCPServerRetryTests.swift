import Foundation
@testable import Swarm
import Testing

@Suite("HTTPMCPServer Retry Tests")
struct HTTPMCPServerRetryTests {
    @Test("Does not retry on HTTP 4xx responses")
    func doesNotRetryOnClientErrors() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://mcp.example.com/api")!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("bad request".utf8))
        }

        let server = HTTPMCPServer(
            url: URL(string: "https://mcp.example.com/api")!,
            name: "retry-test",
            maxRetries: 3,
            session: session
        )

        await #expect(throws: MCPError.self) {
            _ = try await server.listTools()
        }

        #expect(MockURLProtocol.requestCount == 1)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestCount: Int = 0
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestCount = 0
        handler = nil
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("MockURLProtocol.handler not set")
        }

        Self.requestCount += 1

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
