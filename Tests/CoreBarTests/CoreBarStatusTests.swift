import Foundation
import Testing
@testable import CoreBar

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let handler = MockURLProtocol.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
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

  override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
  let config = URLSessionConfiguration.ephemeral
  config.protocolClasses = [MockURLProtocol.self]
  return URLSession(configuration: config)
}

@Suite(.serialized)
struct CoreBarTests {
  @Test func runningStatusCanOpenDashboard() {
    let status = CoreBarStatus(state: .running, activeConnections: 2)
    #expect(status.canOpenDashboard)
  }

  @Test func connectionCountIsNeverNegative() {
    let status = CoreBarStatus(state: .stopped, activeConnections: -5)
    #expect(status.activeConnections == 0)
  }

  @Test func gatewayHealthyResponse() async {
    MockURLProtocol.requestHandler = { request in
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
      let json = """
      {"ok": true, "status": "ok", "version": "v2.1.2", "uptime": 1200}
      """.data(using: .utf8)!
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, json)
    }

    let client = GatewayHealthClient(
      baseURL: URL(string: "http://127.0.0.1:18789")!,
      token: "secret-token",
      session: makeMockSession()
    )

    let result = await client.checkHealth()
    #expect(result.state == .running)
    #expect(result.version == "v2.1.2")
    #expect(result.isConnected)
    #expect(result.error == nil)
  }

  @Test func gatewayDegraded500Response() async {
    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 503,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let client = GatewayHealthClient(
      baseURL: URL(string: "http://127.0.0.1:18789")!,
      session: makeMockSession()
    )

    let result = await client.checkHealth()
    #expect(result.state == .degraded)
    #expect(result.error != nil)
  }

  @Test func gatewayOfflineConnectionRefused() async {
    MockURLProtocol.requestHandler = { _ in
      throw URLError(.cannotConnectToHost)
    }

    let client = GatewayHealthClient(
      baseURL: URL(string: "http://127.0.0.1:18789")!,
      session: makeMockSession()
    )

    let result = await client.checkHealth()
    #expect(result.state == .stopped)
    #expect(!result.isConnected)
    #expect(result.error != nil)
  }

  @Test func gatewayTimeout() async {
    MockURLProtocol.requestHandler = { _ in
      throw URLError(.timedOut)
    }

    let client = GatewayHealthClient(
      baseURL: URL(string: "http://127.0.0.1:18789")!,
      timeout: 1.0,
      session: makeMockSession()
    )

    let result = await client.checkHealth()
    #expect(result.state == .degraded)
    #expect(result.diagnostics.contains("Timed Out"))
  }
}
