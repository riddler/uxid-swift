// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "uxid",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .tvOS(.v18),
    .watchOS(.v11),
    .visionOS(.v2),
  ],
  products: [
    .library(name: "Uxid", targets: ["Uxid"])
  ],
  dependencies: [
    // The documentation build's plugin only: no target depends on it, so
    // nothing links it into the library.
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
  ],
  targets: [
    .target(name: "Uxid"),
    .testTarget(name: "UxidTests", dependencies: ["Uxid"]),
  ],
  swiftLanguageModes: [.v6]
)
