#if os(macOS)
import AppKit
import CoreBar
import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class CoreBarViewModel {
  var healthResult: GatewayHealthResult
  var isChecking: Bool = false
  private let client: GatewayHealthClient
  private var timer: Timer?

  init(client: GatewayHealthClient = GatewayHealthClient()) {
    self.client = client
    self.healthResult = GatewayHealthResult(
      state: .stopped,
      latencyMs: 0,
      diagnostics: "Initializing CoreBlow Gateway monitor...",
      error: nil
    )
  }

  func startMonitoring() {
    refresh()
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refresh()
      }
    }
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
  }

  func refresh() {
    guard !isChecking else { return }
    isChecking = true
    Task {
      let res = await client.checkHealth()
      await MainActor.run {
        self.healthResult = res
        self.isChecking = false
      }
    }
  }

  func openCockpit() {
    Task {
      let url = await client.baseURL
      _ = await MainActor.run {
        NSWorkspace.shared.open(url)
      }
    }
  }

  func copyDiagnostics() {
    let text = """
    CoreBlow Gateway Diagnostics:
    State: \(healthResult.state.rawValue)
    Version: \(healthResult.version ?? "unknown")
    Latency: \(String(format: "%.1f", healthResult.latencyMs))ms
    Timestamp: \(healthResult.timestamp)
    Diagnostics: \(healthResult.diagnostics)
    Error: \(healthResult.error ?? "none")
    """
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }
}

@main
struct CoreBarApp: App {
  @State private var viewModel = CoreBarViewModel()

  var body: some Scene {
    MenuBarExtra {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Circle()
            .fill(statusColor(viewModel.healthResult.state))
            .frame(width: 9, height: 9)
          Text("CoreBlow Gateway")
            .font(.headline)
          Spacer()
          if viewModel.isChecking {
            ProgressView()
              .scaleEffect(0.6)
              .frame(width: 12, height: 12)
          }
        }

        Text(viewModel.healthResult.diagnostics)
          .font(.caption)
          .foregroundColor(.secondary)

        Divider()

        Button("Open Cockpit UI") {
          viewModel.openCockpit()
        }
        .keyboardShortcut("o", modifiers: .command)

        Button("Reconnect Gateway") {
          viewModel.refresh()
        }
        .keyboardShortcut("r", modifiers: .command)

        Button("Copy Diagnostics") {
          viewModel.copyDiagnostics()
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Divider()

        Button("Quit CoreBar") {
          viewModel.quit()
        }
        .keyboardShortcut("q", modifiers: .command)
      }
      .padding(8)
      .onAppear {
        viewModel.startMonitoring()
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: iconName(viewModel.healthResult.state))
          .symbolRenderingMode(.palette)
          .foregroundStyle(statusColor(viewModel.healthResult.state))
        if viewModel.healthResult.state == .running {
          Text("\(Int(viewModel.healthResult.latencyMs))ms")
            .font(.caption2)
        }
      }
    }
    .menuBarExtraStyle(.menu)
  }

  private func statusColor(_ state: CoreBarStatus.ServiceState) -> Color {
    switch state {
    case .running:
      return Color(red: 233 / 255.0, green: 84 / 255.0, blue: 32 / 255.0) // Core Orange #E95420
    case .degraded, .starting:
      return Color.yellow
    case .stopped:
      return Color(red: 23 / 255.0, green: 28 / 255.0, blue: 31 / 255.0) // Graphite #171C1F
    }
  }

  private func iconName(_ state: CoreBarStatus.ServiceState) -> String {
    switch state {
    case .running:
      return "bolt.circle.fill"
    case .degraded, .starting:
      return "exclamationmark.triangle.fill"
    case .stopped:
      return "bolt.slash.circle"
    }
  }
}
#else
@main
struct NonMacOSStub {
  static func main() {
    print("CoreBar is designed for macOS.")
  }
}
#endif
