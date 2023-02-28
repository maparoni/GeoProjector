//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//
// GeoProjector - Native Swift library for drawing map projections
// Copyright (C) 2022 Corporoni Pty Ltd
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
// USA

#if canImport(UIKit)
import UIKit

// MARK: - Image drawing

extension GeoDrawer {
  
  /// Generates an image drawing the provided contents according to the configured
  /// projection, zoom and edge insets. When providing the different colours, the background of
  /// the map projection itself will be drawn, too.
  ///
  /// - Parameters:
  ///   - contents: GeoJSON contents to draw
  ///   - mapBackground: Background of the map itself
  ///   - mapOutline: Stroke colour around the map
  ///   - mapBackdrop: Background to draw outside the map / projection bounds
  /// - Returns: New image
  public func drawImage(_ contents: [Content], mapBackground: UIColor? = nil, mapOutline: UIColor? = nil, mapBackdrop: UIColor? = nil) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = mapBackdrop != nil
    let cgSize = CGSize(width: size.width, height: size.height)
    let bounds = CGRect(origin: .zero, size: cgSize)
    let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
    let image = renderer.image { rendererContext in
      self.draw(
        contents,
        mapBackground: mapBackground?.cgColor,
        mapOutline: mapOutline?.cgColor,
        mapBackdrop: mapBackdrop?.cgColor,
        in: rendererContext.cgContext
      )
    }
    return image
  }
  
}

#endif
