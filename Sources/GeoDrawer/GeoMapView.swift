//
//  GeoMapView.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import SwiftUI

import GeoProjector

@available(iOS 15.0, *)
struct GeoMapView: View {
  enum ProjectionType: String, CaseIterable {
    case flatSquare
    case mercator
    case orthographic
  }
  
  class Model: ObservableObject {
    init(contents: [GeoDrawer.Content], projection: Projection) {
      self.contents = contents
      self.projection = projection
      self.image = nil
      updateImage()
    }
    
    let contents: [GeoDrawer.Content]
    
    var projection: Projection {
      didSet {
        updateImage()
      }
    }
    
    @Published var projectionType: ProjectionType = .flatSquare {
      didSet { updateProjection() }
    }
    
    @Published var refLat: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var refLng: Double = 0 {
      didSet { updateProjection() }
    }

    @Published var image: UIImage?
    
    func updateProjection() {
      switch projectionType {
      case .flatSquare:
        projection = .equirectangular()
      case .mercator:
        projection = .mercator
      case .orthographic:
        projection = .orthographic(reference: .init(latitude: refLat, longitude: refLng))
      }
    }
    
    func updateImage() {
      let drawer = GeoDrawer(/*boundingBox: .init(positions: []),*/ size: .init(width: 200, height: 100), projection: self.projection)
      self.image = drawer.drawImage(self.contents, background: .systemYellow, size: .init(width: 200, height: 150))
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
      
      if model.projectionType == .orthographic {
        Slider(value: $model.refLat, in: -90...90)
        Slider(value: $model.refLng, in: -180...180)
      }
    }
    .padding(.horizontal, 40)
  }
}

#if DEBUG
@available(iOS 15.0, *)
struct GeoMapView_Previews: PreviewProvider {
  static var previews: some View {
    GeoMapView(model: .init(contents: try! GeoDrawer.Content.world(), projection: .mercator))
      .previewLayout(.fixed(width: 250, height: 200))

    GeoMapView(model: .init(contents: try! GeoDrawer.Content.world(), projection: .equirectangular()))
      .previewLayout(.fixed(width: 250, height: 150))

    GeoMapView(model: .init(contents: try! GeoDrawer.Content.world(), projection: .orthographic(reference: .init(latitude: 0, longitude: 0))))
      .previewLayout(.fixed(width: 250, height: 150))
  }
}
#endif
