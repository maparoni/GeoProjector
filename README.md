# GeoProjector (work-in-progress)

This is a Swift-only library to calculate and draw map projections.

*This is in very early days, has some glitches, and is not yet stable. So do not
 use it yet except to satisfy some curiousity that you have.*

- GeoProjector: Map projections, turning coordinates into projected coordinates
  and into screen coordinates.
- GeoDrawer: Draw GeoJSON using whichever projection you choose.

## Goals of this library

- Support a selection of map projections, but not a comprehensive one
- Provide methods for drawing those projections, draw GeoJSON content on top,
  and drawing just a section of the resulting map
- Compatibility with Apple platforms and Linux

## Dependencies

This library is part of the [Maparoni](https://maparoni.app) suite of mapping 
related Swift libraries and depends on:

- [GeoJSONKit](https://github.com/maparoni/GeoJSONKit), a light-weight GeoJSON
  framework.
- [GeoJSONKit-Turf](https://github.com/maparoni/geojsonkit-turf), a fork of
  [turf-swift](https://github.com/mapbox/turf-swift) with GeoJSONKit's GeoJSON
  enums used for the basic data models.

## Credits

The code in this repo is all written by myself, [Adrian Schönig](https://github.com/nighthawk),
but it wouldn't have been able to do this so smoothly without the help of these
precious resources:

- Justin Kunimune's [jkunimune/Map-Projections](https://github.com/jkunimune/Map-Projections), 
  which is comprehensive suite of map projections implemented in Java, including
  some projections of his own making.
- The comprehensive description of [map projections](https://en.wikipedia.org/wiki/Map_projection)
  on Wikipedia.
