//
//  GeoMapView.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if os(iOS)
import SwiftUI

import GeoProjector
import GeoJSONKit

@available(iOS 15.0, *)
struct GeoMapView: View {
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
        projection = Projections.Equirectangular(reference: reference, phiOne: equirectangularPhiOne)
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

#if DEBUG
@available(iOS 15.0, *)
struct GeoMapView_Previews: PreviewProvider {
  static var previews: some View {
    GeoMapView(model: .init(contents: try! GeoDrawer.Content.world()))
  }
}
#endif

#endif // iOS
