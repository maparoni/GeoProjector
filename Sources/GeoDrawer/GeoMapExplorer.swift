//
//  GeoMapExplorer.swift
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

#if DEBUG
#if os(iOS)
import SwiftUI

import GeoProjector
import GeoJSONKit

@available(iOS 15.0, *)
struct GeoMapExplorer: View {
  enum ProjectionType: String, CaseIterable {
    case equirectangular
    case cassini
    case mercator
    case gallPeters
    case equalEarth
    case orthographic
    case azimuthal
  }
  
  class Model: ObservableObject {
    init(contents: [GeoDrawer.Content]) {
      self.contents = contents
      self.projection = Projections.Orthographic()
      self.projectionType = .orthographic
      self.image = nil
      updateImage()
    }
    
    let contents: [GeoDrawer.Content]
    
    var projection: any Projection {
      didSet {
        updateImage()
      }
    }
    
    @Published var projectionType: ProjectionType {
      didSet { updateProjection() }
    }
    
    @Published var refLat: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var refLng: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var equirectangularPhiOne: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var image: UIImage?
    
    func updateProjection() {
      let reference = GeoJSON.Position(latitude: refLat, longitude: refLng)
      
      switch projectionType {
      case .equirectangular:
        projection = Projections.Equirectangular(reference: reference, phiOne: equirectangularPhiOne.toRadians())
      case .cassini:
        projection = Projections.Cassini(reference: reference)
      case .mercator:
        projection = Projections.Mercator(reference: reference)
      case .gallPeters:
        projection = Projections.GallPeters(reference: reference)
      case .equalEarth:
        projection = Projections.EqualEarth(reference: reference)
      case .orthographic:
        projection = Projections.Orthographic(reference: reference)
      case .azimuthal:
        projection = Projections.AzimuthalEquidistant(reference: reference)
      }
    }
    
    func updateImage() {
      let drawer = GeoDrawer(
        /*boundingBox: .init(positions: []),*/
        size: .init(width: 300, height: 300),
        projection: self.projection
      )
      self.image = drawer.drawImage(
        self.contents,
        background: .systemTeal,
        size: .init(width: 300, height: 300)
      )
    }
  }
  
  @ObservedObject var model: Model
  
  var body: some View {
    VStack {
      if let image = model.image {
        Image(uiImage: image)
      } else {
        Text("Loading and creating image...")
      }
      
      Picker("Projection", selection: $model.projectionType) {
        ForEach(ProjectionType.allCases, id: \.self) {
          Text($0.rawValue).tag($0)
        }
      }
      
      Slider(value: $model.refLat, in: -90...90)
      Slider(value: $model.refLng, in: -180...180)
      
      switch model.projectionType {
      case .equirectangular:
        Slider(value: $model.equirectangularPhiOne, in: -90...90)
      case .orthographic, .cassini, .mercator, .gallPeters, .equalEarth, .azimuthal:
        EmptyView()
      }
      
      Spacer()
    }
    .padding(40)
  }
}

@available(iOS 15.0, *)
struct GeoMapExplorer_Previews: PreviewProvider {
  static var previews: some View {
    GeoMapExplorer(model: .init(contents: try! GeoDrawer.Content.world()))
  }
}

#endif // iOS
#endif // DEBUG
