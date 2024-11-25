// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "GeoProjector",
  platforms: [
    .macOS(.v12), .iOS(.v15), .watchOS(.v8), .tvOS(.v15),
    .custom("xros", versionString: "1.0")
  ],
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
    .package(url: "https://github.com/maparoni/geojsonkit-turf", from: "0.1.0"),
//    .package(name: "geojsonkit-turf", path: "../GeoJSONKit-Turf"),
    .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "GeoProjector",
      dependencies: [
        .product(name: "GeoJSONKit", package: "geojsonkit"),
        .product(name: "GeoJSONKitTurf", package: "geojsonkit-turf"),
      ]),
    .testTarget(
      name: "GeoProjectorTests",
      dependencies: [
        "GeoProjector",
      ]),
    .target(
      name: "GeoDrawer",
      dependencies: [
        "GeoProjector",
        .product(name: "Algorithms", package: "swift-algorithms"),
      ]),
  ]
)
