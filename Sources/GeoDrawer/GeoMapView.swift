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
  class Model: ObservableObject {
    init(contents: [GeoDrawer.Content]) {
      Task {
        let drawer = GeoDrawer(/*boundingBox: .init(positions: []),*/ size: .init(width: 200, height: 100))
        self.image = drawer.drawImage(contents, background: .systemYellow, size: .init(width: 200, height: 100))
      }
    }
    
    @Published var image: UIImage?
  }
  
  @ObservedObject var model: Model
  
  var body: some View {
    if let image = model.image {
      Image(uiImage: image)
    } else {
      Text("Loading and creating image...")
    }
  }
}

#if DEBUG
@available(iOS 15.0, *)
struct GeoMapView_Previews: PreviewProvider {
  static var previews: some View {
    GeoMapView(model: .init(contents: try! GeoDrawer.Content.world()))
      .previewLayout(.fixed(width: 250, height: 150))

    GeoMapView(model: .init(contents: try! GeoDrawer.Content.tripGoMini()))
      .previewLayout(.fixed(width: 250, height: 150))
  }
}
#endif
