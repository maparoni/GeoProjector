//
//  GeoDrawer+UIKit.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

#if canImport(UIKit)
import UIKit

// MARK: - Image drawing

extension GeoDrawer {
  
  func drawImage(_ contents: [Content], background: UIColor? = nil, size: CGSize) -> UIImage {
    
    let format = UIGraphicsImageRendererFormat()
    format.opaque = true
    let bounds = CGRect(origin: .zero, size: size)
    let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
    let image = renderer.image { rendererContext in
      self.drawImage(
        contents,
        mapBackground: (background ?? .systemBlue).cgColor,
        mapOutline: UIColor.black.cgColor,
        background: UIColor.white.cgColor,
        size: size,
        in: rendererContext.cgContext
      )
    }
    return image
    
  }
  
}

#endif
