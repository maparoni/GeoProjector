[![License](https://img.shields.io/badge/license-MPL2-ff3079.svg)](https://github.com/maparoni/GeoProjector/blob/main/LICENSE)
[![CI](https://github.com/maparoni/GeoProjector/actions/workflows/swift.yml/badge.svg)](https://github.com/maparoni/GeoProjector/actions/workflows/swift.yml)

# GeoProjector

This is a Swift-only library to calculate and draw map projections.

**This is in early days, has some glitches, and is not yet stable.**

- GeoProjector: Map projections, turning coordinates into projected coordinates
  and into screen coordinates.
- GeoDrawer: Draw GeoJSON using whichever projection you choose.

## Goals of this library

- Support a selection of map projections, but not an exhaustive list
- Provide methods for drawing those projections, draw GeoJSON content on top,
  and drawing just a section of the resulting map
- Provide methods for getting coordinates of projected map points
- Compatibility with Apple platforms and Linux

## Dependencies

This library is part of the [Maparoni](https://maparoni.app) suite of mapping 
related Swift libraries and depends on:

- [GeoJSONKit](https://github.com/maparoni/GeoJSONKit), a light-weight GeoJSON
  framework.
- [GeoJSONKit-Turf](https://github.com/maparoni/geojsonkit-turf), a fork of
  [turf-swift](https://github.com/mapbox/turf-swift) with GeoJSONKit's GeoJSON
  enums used for the basic data models.
  
## Usage

### Installation

**As noted above, this library is not yet stable!** 

To install GeoProjector using the [Swift Package Manager](https://swift.org/package-manager/), 
add the following package to the `dependencies` in your Package.swift file or 
in Xcode:

```swift
.package(
  name: "GeoProjector", url: "https://github.com/maparoni/geoprojector", 
  branch: "main" // no tagged versions yet 
)
```

### Projections

Projections are defined using the `Projection` protocol, which defines the
expected `project` method, but also some additional information, such as the
shape of the map bounds of the projection.

The projections themselves are available through the `Projections` namespace
(i.e., a caseless enum) which provides implementations of different projections.
Note that the implementations are based on radians, but there are various
helper methods to work with GeoJSON and coordinates in degrees.

Example usage:

```swift
import GeoProjector

let projection = Projections.Orthographic(
  reference: GeoJSON.Position(latitude: 0, longitude: 100)
)
let sydney = GeoJSON.Position(latitude: -33.8, longitude: 151.3)
let projected = projection.point(
  for: sydney, 
  size: .init(width: 100, height: 100) // the maximum size of the canvas
)?.0
```

Note that projected points align with what's common on the platform, so macOS
has `(x: 0, y: 0)` for the bottom left map coordinate `(latitude: -180, 
longitude: -90)` while other platforms have it in the top left map coordinate
`(latitude: -180, longitude: 90)`.

### Maps (AppKit)

The GeoDrawer library includes an NSView called GeoMapView and a corresponding
SwiftUI view called GeoMap. You can use these to get a map view to draw content
on.

```swift
import SwiftUI
import GeoDrawer

struct MyMap: View {

  var body: some View {
    GeoMap(
      contents: try! GeoDrawer.Content.world(),
      projection: Projections.Cassini()
    )
  }
  
}
```

## Credits

The code in this repo is all written by myself, [Adrian Schönig](https://github.com/nighthawk),
but it wouldn't have been able to do this so smoothly without the help of these
precious resources:

- Justin Kunimune's [jkunimune/Map-Projections](https://github.com/jkunimune/Map-Projections), 
  which is comprehensive suite of map projections implemented in Java, including
  some projections of his own making.
- The comprehensive description of [map projections](https://en.wikipedia.org/wiki/Map_projection)
  on Wikipedia.

## License

This library is available under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/). 
This means that if you use and modify this library, you have to make your changes also available under the
same license (or a compatible one). As long as you comply with this and keep copyright notices
intact, you can however use the library in closed source projects.

The [examples](Examples/) are public domain and can be adapted freely.
