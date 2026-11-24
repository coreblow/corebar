# CoreBar

Real-time macOS menu bar companion and gateway health monitor for CoreBlow.

## Overview

CoreBar is part of the CoreBlow public repository family. It provides both a lightweight SwiftUI macOS menu bar app (`corebar`) and an async Swift library (`CoreBar`) for monitoring CoreBlow Gateway connectivity, latency, and service state.

This repository follows the same ecosystem split that CoreBlow uses to keep release surfaces small, auditable, and independently governed.

## Repository Role

- Status: Active
- Phase: 4
- Priority: desktop
- Kind: control-plane
- Family: CoreBlow public repository family
- Branding: CoreBlow

## Features

- **macOS Menu Bar Companion**: SwiftUI `MenuBarExtra` status item displaying live Gateway state and latency using the CoreBlow brand palette (`#E95420` Core Orange, `#171C1F` Graphite).
- **Gateway Health Client**: Async actor-based Swift client polling `http://127.0.0.1:18789/health` with sub-millisecond latency tracking and error classification (healthy, degraded, offline, timeout).
- **Quick Actions**: One-click shortcuts to open the CoreBlow Cockpit UI, reconnect/poll gateway, copy diagnostic snapshots to the clipboard, and quit.
- **Swift 6 Strict Concurrency**: Fully compliant with Swift 6 Sendable requirements and modern Observation framework.

## Usage & Development

### Build Executable & Library

```sh
swift build
```

The compiled binary will be placed at `.build/debug/corebar`.

### Run Test Suite

```sh
swift test
```

### Run CoreBar Menu App

```sh
swift run corebar
```

## Release Policy

Do not publish packages, tags, installers, or release artifacts from this repository without explicit CoreBlow release approval.

Version changes must follow the coordinated CoreBlow release plan.

## Links

- [CoreBlow](https://github.com/coreblow/coreblow)
- [Documentation](https://docs.coreblow.com)
- [Website](https://coreblow.com)
- [Security Policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
