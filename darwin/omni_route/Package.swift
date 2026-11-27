// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "omni_route",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "omni-route", targets: ["omni_route"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "omni_route",
      dependencies: [],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
