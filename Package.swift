// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CoreBar",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "CoreBar", targets: ["CoreBar"]),
    .executable(name: "corebar", targets: ["CoreBarMenu"])
  ],
  targets: [
    .target(
      name: "CoreBar",
      path: "Sources/CoreBar"
    ),
    .executableTarget(
      name: "CoreBarMenu",
      dependencies: ["CoreBar"],
      path: "Sources/CoreBarApp"
    ),
    .testTarget(
      name: "CoreBarTests",
      dependencies: ["CoreBar"],
      path: "Tests/CoreBarTests"
    )
  ]
)
