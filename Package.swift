// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "GeoProjector",
  products: [
    .library(
      name: "GeoProjector",
      targets: ["GeoProjector"]),
    .library(
      name: "GeoDrawer",
      targets: ["GeoDrawer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/maparoni/geojsonkit.git", from: "0.5.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "GeoProjector",
      dependencies: [
        .product(name: "GeoJSONKit", package: "geojsonkit")
      ]),
    .testTarget(
      name: "GeoProjectorTests",
      dependencies: ["GeoProjector"]),
    .target(
      name: "GeoDrawer",
      dependencies: [
        "GeoProjector"
      ]),
  ]
)
