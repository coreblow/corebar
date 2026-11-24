import Foundation

public struct GatewayHealthResult: Equatable, Sendable {
  public let state: CoreBarStatus.ServiceState
  public let latencyMs: Double
  public let version: String?
  public let diagnostics: String
  public let error: String?
  public let timestamp: Date

  public init(
    state: CoreBarStatus.ServiceState,
    latencyMs: Double,
    version: String? = nil,
    diagnostics: String,
    error: String? = nil,
    timestamp: Date = Date()
  ) {
    self.state = state
    self.latencyMs = max(0, latencyMs)
    self.version = version
    self.diagnostics = diagnostics
    self.error = error
    self.timestamp = timestamp
  }

  public var isConnected: Bool {
    state == .running || state == .degraded
  }
}

public actor GatewayHealthClient {
  public let baseURL: URL
  public let token: String?
  public let timeout: TimeInterval
  private let session: URLSession

  public init(
    baseURL: URL = URL(string: "http://127.0.0.1:18789")!,
    token: String? = nil,
    timeout: TimeInterval = 5.0,
    session: URLSession? = nil
  ) {
    self.baseURL = baseURL
    self.token = token
    self.timeout = timeout
    if let session = session {
      self.session = session
    } else {
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = timeout
      config.timeoutIntervalForResource = timeout
      self.session = URLSession(configuration: config)
    }
  }

  public func checkHealth() async -> GatewayHealthResult {
    let healthURL = baseURL.appendingPathComponent("health")
    var request = URLRequest(url: healthURL)
    request.httpMethod = "GET"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token = token, !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let startTime = CFAbsoluteTimeGetCurrent()
    do {
      let (data, response) = try await session.data(for: request)
      let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

      guard let httpResponse = response as? HTTPURLResponse else {
        return GatewayHealthResult(
          state: .stopped,
          latencyMs: elapsedMs,
          diagnostics: "Invalid protocol response from gateway",
          error: "Non-HTTP response"
        )
      }

      if httpResponse.statusCode == 200 {
        // Parse health JSON
        var version: String? = nil
        var isDegraded = false
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          version = json["version"] as? String
          if let status = json["status"] as? String, status.lowercased() == "degraded" {
            isDegraded = true
          }
          if let ok = json["ok"] as? Bool, !ok {
            isDegraded = true
          }
        }
        let serviceState: CoreBarStatus.ServiceState = isDegraded ? .degraded : .running
        let diag = "CoreBlow Gateway Healthy (\(version ?? "v2.1.2")) at \(baseURL.host ?? "127.0.0.1") - \(String(format: "%.1f", elapsedMs))ms"
        return GatewayHealthResult(
          state: serviceState,
          latencyMs: elapsedMs,
          version: version,
          diagnostics: diag
        )
      } else if httpResponse.statusCode >= 500 {
        let diag = "CoreBlow Gateway Degraded (HTTP \(httpResponse.statusCode))"
        return GatewayHealthResult(
          state: .degraded,
          latencyMs: elapsedMs,
          diagnostics: diag,
          error: "Gateway internal status: \(httpResponse.statusCode)"
        )
      } else {
        let diag = "CoreBlow Gateway Returned HTTP \(httpResponse.statusCode)"
        return GatewayHealthResult(
          state: .stopped,
          latencyMs: elapsedMs,
          diagnostics: diag,
          error: "HTTP error: \(httpResponse.statusCode)"
        )
      }
    } catch let urlError as URLError {
      let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
      let diag: String
      let state: CoreBarStatus.ServiceState
      if urlError.code == .timedOut {
        diag = "CoreBlow Gateway Request Timed Out (> \(String(format: "%.1f", timeout))s)"
        state = .degraded
      } else {
        diag = "CoreBlow Gateway Offline (\(urlError.localizedDescription))"
        state = .stopped
      }
      return GatewayHealthResult(
        state: state,
        latencyMs: elapsedMs,
        diagnostics: diag,
        error: urlError.localizedDescription
      )
    } catch {
      let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
      return GatewayHealthResult(
        state: .stopped,
        latencyMs: elapsedMs,
        diagnostics: "CoreBlow Gateway Check Error: \(error.localizedDescription)",
        error: error.localizedDescription
      )
    }
  }
}
