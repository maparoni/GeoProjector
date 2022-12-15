//
//  GeoJSON+Continents.swift
//  
//
//  Created by Adrian Schönig on 2/12/2022.
//

import GeoJSONKit

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension GeoJSON.GeometryObject {
  public var geometries: [GeoJSON.Geometry] {
    switch self {
    case .single(let geo): return [geo]
    case .multi(let geos): return geos
    case .collection(let geoObjects): return geoObjects.flatMap(\.geometries)
    }
  }
}

extension GeoDrawer.Content {

  public static func content(for geoJSON: GeoJSON, color: GeoDrawer.Color) -> [GeoDrawer.Content] {
    let geometries: [GeoJSON.Geometry]
    switch geoJSON.object {
    case .geometry(let geo): geometries = geo.geometries
    case .feature(let feature): geometries = feature.geometry.geometries
    case .featureCollection(let features): geometries = features.flatMap(\.geometry.geometries)
    }

    return geometries.map { geometry in
      switch geometry {
      case .polygon(let polygon):
        return .polygon(polygon, fill: color)
      case .lineString(let line):
        return .line(line, stroke: color)
      case .point(let position):
        return .circle(position, radius: 1, fill: color)
      }
    }
  }
  
  public static func world() throws -> [GeoDrawer.Content] {
    let geoJSON = try GeoJSON(geoJSONString: """
          {"coordinates":[[[[-45.34,-78.69],[-43.73,-78.80],[-43.13,-79.95],[-54.16,-80.87],[-50.54,-79.63],[-49.11,-78.09],[-43.81,-78.24],[-45.34,-78.69]]],[[[-57.80,-63.81],[-57.15,-64.08],[-58.10,-64.38],[-57.80,-63.81]]],[[[-57.02,-63.28],[-61.93,-65.19],[-61.77,-66.10],[-60.57,-65.94],[-60.97,-66.32],[-63.66,-66.21],[-65.57,-67.72],[-64.81,-68.68],[-62.87,-68.42],[-63.80,-68.94],[-60.92,-71.22],[-62.44,-71.91],[-60.87,-72.04],[-61.46,-72.40],[-60.27,-73.04],[-62.00,-73.10],[-60.79,-73.57],[-61.79,-73.90],[-61.06,-74.30],[-64.35,-75.27],[-63.08,-75.35],[-63.62,-75.50],[-70.58,-76.71],[-77.26,-76.56],[-75.81,-77.41],[-72.72,-77.57],[-73.62,-78.02],[-80.76,-77.66],[-81.39,-77.83],[-77.36,-78.44],[-83.79,-78.42],[-80.80,-79.52],[-76.32,-79.37],[-79.68,-79.98],[-76.27,-80.08],[-75.13,-80.74],[-75.72,-80.81],[-62.41,-81.55],[-65.80,-81.88],[-60.70,-82.16],[-62.79,-82.51],[-59.87,-83.42],[-53.31,-82.15],[-46.66,-81.95],[-45.52,-82.52],[-39.24,-80.95],[-22.90,-79.98],[-36.41,-78.75],[-34.13,-77.44],[-29.15,-76.42],[-18.65,-75.48],[-17.61,-74.40],[-14.78,-74.06],[-16.60,-73.63],[-15.97,-73.30],[-11.38,-72.41],[-11.80,-71.25],[-9.94,-70.94],[-8.61,-71.69],[-5.67,-70.73],[-5.57,-71.35],[-0.62,-71.68],[9.12,-70.07],[11.82,-70.78],[16.63,-70.16],[19.29,-70.24],[19.56,-70.94],[22.01,-70.31],[27.27,-70.98],[32.85,-69.94],[32.53,-69.11],[33.21,-68.66],[38.71,-70.16],[40.26,-68.80],[46.58,-67.27],[48.65,-67.84],[49.05,-66.88],[50.81,-67.21],[50.79,-66.27],[54.71,-65.90],[57.27,-66.58],[56.24,-66.61],[56.26,-67.29],[69.20,-67.78],[70.04,-68.42],[69.74,-69.29],[67.22,-70.25],[69.09,-70.79],[67.28,-72.07],[67.16,-73.26],[71.53,-71.61],[73.47,-69.78],[75.52,-69.90],[78.74,-68.26],[84.59,-67.11],[102.91,-65.87],[108.72,-66.93],[112.76,-65.82],[115.68,-66.64],[114.03,-67.19],[114.67,-67.34],[119.72,-67.31],[125.73,-66.37],[129.20,-67.10],[129.91,-66.35],[133.60,-66.10],[143.50,-66.84],[144.54,-67.03],[143.85,-67.81],[145.91,-67.58],[147.03,-68.41],[153.09,-68.87],[153.70,-68.30],[159.82,-69.52],[162.41,-71.08],[162.31,-70.28],[170.53,-71.53],[170.27,-72.58],[168.59,-72.38],[169.88,-72.71],[169.55,-73.09],[166.56,-72.95],[167.92,-73.35],[165.49,-73.90],[164.55,-73.32],[165.46,-74.52],[163.39,-74.36],[160.97,-75.28],[162.84,-75.79],[162.42,-76.89],[164.50,-77.85],[164.03,-78.17],[167.00,-78.50],[161.60,-78.50],[161.02,-79.44],[159.63,-79.52],[161.47,-79.90],[158.47,-80.36],[160.75,-80.38],[160.10,-80.59],[161.34,-80.78],[159.74,-80.79],[163.77,-82.12],[161.09,-82.39],[180,-84.35],[180,-90],[-180,-89.50],[-180,-84.51],[-179.13,-84.33],[-155.70,-84.87],[-166.01,-84.39],[-163.00,-84.36],[-174.33,-82.81],[-157.55,-83.39],[-156.91,-83.23],[-158.46,-83.16],[-152.54,-82.54],[-157.05,-81.35],[-156.45,-81.14],[-147.62,-80.92],[-151.01,-80.42],[-147.15,-79.94],[-156.52,-78.66],[-153.81,-78.23],[-158.18,-78.00],[-157.92,-77.05],[-145.42,-77.50],[-145.95,-77.36],[-145.39,-76.77],[-149.63,-76.42],[-145.35,-76.43],[-146.49,-76.08],[-135.34,-74.56],[-121.91,-74.76],[-115.02,-74.48],[-114.21,-73.86],[-113.22,-74.40],[-114.05,-74.62],[-113.65,-74.96],[-111.54,-74.80],[-111.40,-74.18],[-110.24,-74.37],[-111.52,-75.10],[-110.78,-75.19],[-98.77,-75.32],[-102.73,-73.93],[-99.21,-73.64],[-103.31,-72.97],[-102.68,-72.72],[-96.15,-73.31],[-88.59,-72.68],[-82.34,-73.82],[-80.01,-72.99],[-76.87,-73.45],[-77.24,-73.81],[-68.91,-73.10],[-66.93,-72.24],[-68.82,-69.43],[-66.85,-69.20],[-67.35,-68.91],[-66.73,-67.73],[-67.46,-67.04],[-66.56,-67.27],[-63.68,-65.52],[-64.08,-65.19],[-57.02,-63.28]]],[[[-68.34,-54.99],[-68.89,-55.07],[-68.04,-55.56],[-69.98,-55.16],[-68.34,-54.99]]],[[[-67.80,-54.91],[-67.30,-54.92],[-68.08,-55.23],[-67.80,-54.91]]],[[[-70.50,-54.95],[-70.26,-55.11],[-70.80,-55.07],[-70.50,-54.95]]],[[[-71.52,-53.98],[-71.01,-54.09],[-71.66,-54.22],[-71.52,-53.98]]],[[[-71.86,-53.88],[-71.74,-54.23],[-72.24,-53.96],[-71.86,-53.88]]],[[[-70.41,-53.87],[-70.86,-54.05],[-70.51,-53.55],[-70.41,-53.87]]],[[[-73.01,-53.48],[-72.52,-54.07],[-73.53,-53.75],[-73.01,-53.48]]],[[[-74.67,-52.72],[-73.17,-53.31],[-74.31,-53.09],[-74.67,-52.72]]],[[[-69.18,-52.66],[-65.40,-54.64],[-71.65,-54.65],[-69.18,-54.57],[-70.43,-53.04],[-69.18,-52.66]]],[[[-73.72,-52.40],[-73.86,-52.70],[-74.14,-52.70],[-73.72,-52.40]]],[[[-74.83,-52.21],[-74.54,-52.24],[-74.59,-52.39],[-74.83,-52.21]]],[[[-74.85,-51.63],[-74.78,-51.81],[-74.94,-52.11],[-74.85,-51.63]]],[[[-74.47,-50.79],[-74.39,-51.08],[-74.96,-50.94],[-74.47,-50.79]]],[[[-75.29,-50.02],[-74.96,-50.07],[-75.46,-50.35],[-75.29,-50.02]]],[[[-75.42,-48.87],[-75.23,-49.00],[-75.65,-48.91],[-75.42,-48.87]]],[[[-74.68,-48.72],[-74.55,-49.65],[-75.46,-49.33],[-74.68,-48.72]]],[[[-74.72,-48.22],[-74.60,-48.45],[-75.02,-48.52],[-74.72,-48.22]]],[[[-75.12,-48.10],[-74.83,-48.34],[-75.03,-48.44],[-75.12,-48.10]]],[[[-75.34,-48.05],[-75.09,-48.54],[-75.55,-48.29],[-75.34,-48.05]]],[[[-73.84,-45.00],[-73.73,-45.26],[-74.23,-45.07],[-73.84,-45.00]]],[[[-73.92,-44.62],[-74.24,-44.80],[-74.40,-44.62],[-73.92,-44.62]]],[[[-72.93,-44.45],[-73.25,-44.94],[-73.45,-44.66],[-72.93,-44.45]]],[[[-73.95,-41.81],[-73.80,-43.40],[-74.29,-43.31],[-73.95,-41.81]]],[[[144.76,-40.72],[148.20,-40.84],[147.88,-42.78],[146.02,-43.55],[144.76,-40.72]]],[[[172.90,-40.50],[173.98,-40.90],[174.08,-41.96],[170.69,-45.68],[168.90,-46.65],[166.52,-45.99],[172.90,-40.50]]],[[[173.07,-34.41],[176.08,-37.67],[178.27,-37.55],[178.18,-38.63],[175.66,-41.42],[175.06,-41.38],[174.96,-39.91],[173.85,-39.46],[174.97,-37.74],[173.07,-34.41]]],[[[49.35,-12.09],[50.43,-15.55],[49.68,-16.02],[47.14,-24.81],[45.20,-25.58],[43.92,-24.77],[43.24,-22.33],[44.47,-19.98],[44.04,-17.30],[44.40,-16.37],[46.35,-15.95],[47.76,-14.60],[49.35,-12.09]]],[[[142.54,-10.70],[143.70,-14.20],[145.29,-15.25],[146.42,-19.02],[148.68,-20.23],[149.66,-22.49],[150.79,-22.84],[153.13,-26.10],[153.58,-28.60],[152.98,-31.16],[149.61,-37.71],[146.18,-38.75],[145.03,-38.00],[143.20,-38.74],[140.71,-38.07],[139.18,-35.69],[138.15,-35.65],[138.22,-34.32],[137.19,-35.22],[137.90,-32.78],[135.70,-34.89],[134.22,-32.52],[131.17,-31.47],[125.87,-32.33],[123.26,-33.98],[120.17,-33.93],[117.90,-35.01],[115.01,-34.26],[115.74,-31.92],[113.29,-26.39],[113.76,-26.59],[113.45,-25.60],[114.06,-26.43],[114.26,-25.97],[113.43,-24.53],[113.88,-22.11],[120.80,-19.69],[123.00,-16.37],[123.87,-17.21],[123.53,-16.26],[124.59,-16.40],[125.60,-14.22],[126.91,-13.73],[128.08,-15.16],[129.98,-14.80],[129.60,-14.03],[130.35,-12.78],[132.60,-12.11],[132.55,-11.34],[136.82,-12.21],[135.73,-15.10],[140.73,-17.51],[142.54,-10.70]]],[[[106.15,-6.00],[111.67,-6.73],[114.27,-7.70],[114.36,-8.35],[106.79,-7.43],[105.53,-6.87],[106.15,-6.00]]],[[[-51.22,-0.55],[-51.80,-1.45],[-51.67,-0.84],[-51.22,-0.55]]],[[[132.43,-0.34],[133.90,-0.73],[135.11,-3.36],[137.98,-1.54],[144.40,-3.80],[147.62,-6.10],[147.06,-7.14],[150.27,-10.68],[147.78,-10.05],[144.67,-7.58],[142.45,-8.32],[143.39,-8.91],[142.42,-9.22],[138.97,-8.22],[139.18,-6.97],[137.91,-5.38],[134.07,-3.81],[133.87,-3.05],[132.91,-4.09],[132.15,-2.94],[133.94,-2.16],[132.38,-2.25],[131.27,-1.37],[132.43,-0.34]]],[[[-50.09,-0.13],[-48.42,-0.25],[-48.52,-0.77],[-50.15,-1.77],[-50.73,-0.55],[-50.09,-0.13]]],[[[125.06,1.67],[124.19,0.37],[120.21,0.29],[120.61,-1.28],[123.38,-1.00],[121.66,-1.92],[122.66,-4.10],[121.50,-4.67],[120.73,-2.63],[120.43,-5.52],[119.42,-5.57],[119.50,-3.57],[118.78,-3.06],[120.09,0.75],[120.81,1.29],[123.92,0.83],[125.06,1.67]]],[[[95.50,5.60],[97.66,5.07],[102.64,0.24],[103.62,0.33],[103.37,-0.64],[104.71,-2.51],[105.99,-2.96],[105.83,-5.59],[104.29,-5.62],[102.29,-3.96],[98.81,1.61],[95.45,4.79],[95.50,5.60]]],[[[-162.38,6.43],[-162.40,6.43],[-162.40,6.44],[-162.38,6.44],[-162.38,6.43]]],[[[116.83,6.96],[119.05,5.41],[117.30,3.63],[118.71,1.26],[116.23,-1.77],[115.96,-3.60],[114.71,-4.17],[114.15,-3.37],[110.15,-2.62],[109.10,-0.40],[109.25,1.66],[110.96,1.50],[116.83,6.96]]],[[[125.64,9.61],[126.58,7.32],[126.21,6.39],[125.84,7.35],[125.48,6.97],[125.32,5.57],[124.24,6.18],[123.95,7.67],[122.26,7.24],[122.48,8.07],[124.15,8.19],[125.64,9.61]]],[[[124.44,11.44],[125.03,11.10],[125.04,10.04],[124.44,11.44]]],[[[124.91,12.56],[125.63,11.34],[124.27,12.53],[124.91,12.56]]],[[[120.90,18.56],[122.38,17.34],[121.56,15.61],[121.91,14.00],[122.90,14.22],[124.07,13.01],[122.41,13.96],[122.64,13.45],[121.29,13.61],[120.09,14.79],[119.78,16.32],[120.20,16.03],[120.90,18.56]]],[[[-72.77,19.94],[-69.35,19.30],[-68.64,18.22],[-74.33,18.28],[-72.35,18.53],[-72.77,19.94]]],[[[113.55,22.16],[113.58,22.12],[113.54,22.11],[113.55,22.16]]],[[[113.55,22.21],[113.53,22.18],[113.53,22.22],[113.55,22.21]]],[[[90.82,22.15],[90.61,22.02],[90.64,22.54],[90.82,22.15]]],[[[-81.18,23.05],[-74.14,20.25],[-77.29,19.90],[-78.68,21.55],[-81.87,22.67],[-84.92,21.83],[-83.32,22.95],[-81.18,23.05]]],[[[32.98,31.08],[32.98,31.07],[32.96,31.08],[32.98,31.08]]],[[[130.99,33.89],[131.87,32.73],[130.72,31.04],[130.59,32.73],[129.68,33.09],[130.99,33.89]]],[[[23.44,38.89],[24.24,38.30],[22.83,38.83],[23.44,38.89]]],[[[26.41,39.32],[26.59,39.01],[25.85,39.17],[26.41,39.32]]],[[[53.50,39.58],[53.50,39.50],[53.46,39.58],[53.50,39.58]]],[[[50.60,40.33],[50.61,40.29],[50.57,40.31],[50.60,40.33]]],[[[50.32,40.48],[50.39,40.42],[50.35,40.39],[50.32,40.48]]],[[[-72.24,41.13],[-72.56,40.94],[-71.85,41.07],[-73.75,40.58],[-72.24,41.13]]],[[[141.27,41.35],[141.95,39.46],[140.02,35.03],[140.07,35.54],[139.05,34.77],[136.85,35.00],[135.49,33.54],[134.83,34.72],[132.16,33.84],[130.89,34.34],[133.09,35.60],[135.64,35.54],[137.09,37.47],[137.05,36.96],[138.55,37.37],[139.96,40.40],[141.27,41.35]]],[[[50.34,45.08],[50.28,44.95],[50.27,45.07],[50.34,45.08]]],[[[142.01,45.45],[143.75,44.11],[145.16,44.19],[145.38,43.25],[143.26,41.98],[140.73,42.56],[140.28,42.30],[141.19,41.79],[140.27,41.48],[139.76,42.31],[141.37,43.56],[142.01,45.45]]],[[[29.80,45.61],[29.73,45.59],[30.07,45.79],[29.80,45.61]]],[[[-55.88,51.61],[-56.77,49.95],[-55.77,49.95],[-55.36,49.06],[-53.47,49.26],[-53.80,47.67],[-52.92,48.17],[-53.06,46.66],[-53.94,46.86],[-54.07,47.85],[-55.75,46.86],[-54.98,47.50],[-56.02,47.49],[-55.73,47.92],[-59.27,47.60],[-55.88,51.61]]],[[[-128.62,53.15],[-128.92,52.67],[-129.07,53.30],[-128.62,53.15]]],[[[-129.75,53.66],[-129.40,53.39],[-130.21,53.73],[-129.75,53.66]]],[[[142.84,54.28],[144.72,48.67],[143.17,49.24],[142.54,47.76],[143.47,46.10],[142.73,46.69],[142.09,45.90],[141.69,52.16],[142.84,54.28]]],[[[-163.75,55.06],[-163.32,54.76],[-164.60,54.40],[-163.75,55.06]]],[[[-7.12,55.28],[-5.55,54.29],[-6.20,52.54],[-10.05,51.60],[-9.61,51.86],[-10.27,52.13],[-8.78,52.66],[-9.93,52.55],[-9.09,53.12],[-10.06,53.41],[-9.99,54.10],[-7.12,55.28]]],[[[-131.20,55.94],[-130.97,55.53],[-131.78,55.42],[-131.20,55.94]]],[[[-3.34,58.65],[-4.40,57.60],[-1.76,57.49],[-3.67,56.05],[-1.72,55.61],[-0.11,54.13],[0.08,52.93],[1.27,52.92],[1.62,52.18],[0.72,51.72],[0.86,50.92],[-5.66,50.04],[-2.49,51.69],[-5.02,51.61],[-2.79,54.22],[-3.56,54.64],[-3.14,54.93],[-4.71,54.81],[-4.88,55.82],[-5.48,55.56],[-5.20,56.44],[-6.18,56.68],[-4.56,58.57],[-3.34,58.65]]],[[[22.83,60.19],[22.48,60.00],[22.44,60.22],[22.83,60.19]]],[[[-16.02,66.53],[-14.56,66.38],[-14.77,65.73],[-13.50,65.09],[-18.78,63.39],[-22.33,63.86],[-21.51,64.64],[-23.57,64.80],[-22.07,65.36],[-24.19,65.50],[-22.44,66.42],[-21.29,65.55],[-16.02,66.53]]],[[[-179.71,68.91],[-175.12,67.49],[-174.60,66.57],[-171.89,66.97],[-169.90,66.16],[-172.68,65.70],[-172.46,64.55],[-173.50,64.34],[-178.28,65.44],[-178.53,66.27],[-179.57,66.11],[-179.58,65.20],[-179.71,68.91]]],[[[-52.72,69.92],[-52.21,69.83],[-52.82,69.35],[-54.77,69.59],[-54.32,70.32],[-52.72,69.92]]],[[[-25.47,70.77],[-28.06,70.43],[-25.70,71.08],[-25.47,70.77]]],[[[-178.73,71.57],[-177.71,71.30],[-179.99,70.99],[-178.73,71.57]]],[[[-94.45,71.88],[-92.95,71.30],[-91.96,69.53],[-90.46,69.49],[-91.44,69.35],[-90.47,68.33],[-89.33,69.24],[-88.24,68.93],[-88.26,67.79],[-87.37,67.27],[-84.80,68.73],[-85.53,69.46],[-84.33,69.85],[-81.63,69.24],[-82.42,68.47],[-81.33,67.53],[-83.49,66.36],[-84.91,67.06],[-84.00,66.49],[-86.68,66.51],[-85.95,66.19],[-87.25,65.36],[-91.31,65.97],[-86.97,65.17],[-88.11,64.14],[-91.10,63.62],[-93.77,64.19],[-90.68,63.33],[-93.13,62.34],[-94.67,60.30],[-94.32,58.35],[-93.35,58.74],[-92.66,57.00],[-90.85,57.26],[-82.56,55.14],[-80.83,51.15],[-79.35,50.78],[-78.51,52.25],[-79.49,54.42],[-76.53,56.34],[-76.94,57.81],[-78.40,58.62],[-77.18,60.06],[-78.14,62.10],[-73.69,62.48],[-71.56,61.21],[-69.58,61.08],[-69.62,60.07],[-70.99,60.07],[-69.52,59.67],[-70.04,58.80],[-68.41,58.82],[-69.36,57.77],[-65.99,58.62],[-64.37,60.12],[-62.91,58.75],[-63.20,58.06],[-61.47,57.15],[-62.48,56.77],[-60.67,55.79],[-60.65,55.05],[-57.71,54.64],[-60.73,53.75],[-57.83,54.20],[-56.05,53.58],[-55.74,52.49],[-60.09,50.24],[-66.46,50.26],[-69.40,48.36],[-70.98,48.46],[-70.01,47.70],[-74.51,45.12],[-68.46,48.52],[-65.68,49.24],[-64.17,48.64],[-66.78,48.00],[-64.68,47.74],[-64.61,46.38],[-61.13,45.35],[-65.32,43.69],[-65.88,44.53],[-63.84,45.27],[-66.95,45.18],[-70.05,43.82],[-70.74,43.08],[-70.27,41.73],[-73.76,40.91],[-74.87,38.94],[-75.02,40.01],[-75.47,39.77],[-75.10,38.31],[-75.74,37.52],[-75.93,39.36],[-76.45,38.29],[-77.01,38.84],[-76.40,37.96],[-76.88,37.25],[-75.56,35.89],[-76.34,36.14],[-76.87,35.45],[-76.33,34.97],[-81.26,31.75],[-80.03,26.55],[-80.39,25.29],[-82.47,27.13],[-82.79,29.10],[-84.02,30.10],[-87.94,30.65],[-90.42,30.18],[-89.29,29.35],[-93.70,29.74],[-96.43,28.76],[-97.61,27.29],[-97.16,25.82],[-97.80,22.34],[-96.31,19.46],[-94.62,18.28],[-91.61,18.44],[-90.22,21.09],[-87.04,21.60],[-88.88,16.02],[-83.35,15.22],[-83.74,10.97],[-82.10,8.93],[-79.19,9.53],[-77.05,8.27],[-74.84,11.08],[-71.68,12.39],[-71.15,12.17],[-71.96,11.59],[-71.74,9.21],[-70.29,11.87],[-68.24,10.57],[-65.45,10.14],[-61.89,10.74],[-62.89,10.53],[-60.85,9.44],[-61.52,8.59],[-59.09,8.00],[-58.61,6.50],[-53.00,5.45],[-51.08,3.59],[-49.97,1.07],[-52.44,-1.44],[-51.03,-1.03],[-49.50,-2.31],[-48.11,-0.72],[-47.10,-0.70],[-44.87,-1.42],[-44.65,-2.85],[-43.31,-2.34],[-39.61,-3.05],[-37.11,-4.92],[-35.58,-5.11],[-34.95,-6.53],[-35.23,-9.04],[-39.08,-13.53],[-39.25,-17.82],[-40.96,-21.94],[-42.01,-22.98],[-44.60,-23.05],[-48.68,-25.41],[-48.74,-28.42],[-52.03,-32.10],[-50.56,-30.39],[-51.05,-30.26],[-54.23,-34.68],[-57.85,-34.47],[-58.15,-32.57],[-58.47,-34.49],[-57.16,-35.37],[-56.88,-37.16],[-58.01,-38.36],[-62.02,-38.93],[-62.48,-40.93],[-65.15,-40.90],[-65.07,-41.95],[-63.57,-42.59],[-64.92,-42.64],[-65.64,-45.04],[-67.13,-45.42],[-67.57,-46.32],[-65.72,-47.30],[-67.89,-49.99],[-68.91,-49.98],[-68.41,-50.11],[-69.49,-51.58],[-68.68,-52.00],[-71.47,-53.82],[-72.44,-53.42],[-71.47,-53.13],[-72.87,-53.38],[-71.94,-52.66],[-73.62,-52.74],[-72.66,-51.60],[-73.28,-52.10],[-74.59,-50.24],[-73.95,-50.28],[-74.26,-48.28],[-73.29,-48.15],[-74.71,-47.73],[-74.32,-46.77],[-75.32,-46.64],[-74.69,-45.84],[-73.51,-46.30],[-72.64,-44.51],[-73.15,-44.26],[-72.30,-41.38],[-73.27,-41.78],[-73.93,-41.09],[-73.20,-39.19],[-73.68,-37.63],[-71.43,-32.42],[-70.31,-18.43],[-75.85,-14.70],[-81.30,-4.72],[-79.80,-2.74],[-80.68,-2.40],[-80.49,-0.38],[-77.05,3.88],[-78.27,7.66],[-77.73,8.13],[-79.51,8.96],[-80.88,7.23],[-85.84,10.23],[-87.47,13.24],[-91.63,14.10],[-94.07,16.14],[-96.54,15.66],[-103.49,18.33],[-105.46,19.95],[-105.74,22.54],[-109.37,25.63],[-109.44,26.67],[-111.92,28.72],[-113.13,31.05],[-114.95,31.91],[-114.42,29.90],[-109.42,23.33],[-109.80,22.95],[-111.84,24.65],[-112.26,26.05],[-114.80,27.62],[-114.09,28.30],[-117.50,33.33],[-120.29,34.46],[-122.32,37.11],[-121.77,38.01],[-122.76,37.93],[-124.38,40.48],[-123.56,46.21],[-124.73,48.17],[-122.69,47.97],[-123.04,47.15],[-122.55,47.24],[-122.49,48.73],[-124.43,49.77],[-124.80,50.91],[-127.53,51.00],[-127.05,52.87],[-127.96,52.32],[-128.88,53.47],[-127.87,53.22],[-129.72,53.67],[-130.43,54.54],[-129.67,55.37],[-130.67,54.77],[-131.00,56.11],[-131.88,55.61],[-134.00,58.39],[-135.22,59.09],[-135.88,58.37],[-136.94,59.02],[-136.08,58.49],[-137.07,58.39],[-139.85,59.54],[-139.01,59.84],[-139.48,60.02],[-144.24,60.03],[-148.13,61.08],[-148.43,59.95],[-151.74,59.16],[-151.41,60.70],[-149.12,60.88],[-149.32,61.47],[-152.80,60.23],[-154.14,59.38],[-153.91,58.60],[-156.50,57.06],[-163.19,55.13],[-160.71,55.72],[-156.96,58.73],[-161.91,58.63],[-162.22,60.50],[-164.12,59.84],[-164.87,60.84],[-163.86,60.77],[-166.18,61.67],[-164.14,63.26],[-161.05,63.57],[-160.83,64.61],[-166.00,64.57],[-168.09,65.59],[-163.98,66.61],[-161.17,66.22],[-162.63,66.88],[-160.45,66.39],[-166.64,68.34],[-156.68,71.35],[-135.40,68.68],[-135.86,68.90],[-135.10,69.46],[-129.84,70.15],[-133.25,68.90],[-132.72,68.79],[-127.44,70.40],[-125.68,69.39],[-124.49,70.05],[-123.99,69.35],[-121.64,69.78],[-115.44,68.94],[-114.20,68.57],[-115.24,68.18],[-114.26,67.72],[-109.83,67.87],[-107.56,66.53],[-107.96,67.68],[-106.07,68.39],[-108.69,68.25],[-108.28,68.62],[-97.41,67.61],[-98.68,68.35],[-97.70,68.52],[-96.00,68.25],[-96.24,67.26],[-95.35,67.04],[-96.37,67.08],[-95.86,66.76],[-95.53,67.88],[-93.44,68.61],[-94.41,68.72],[-93.61,69.43],[-96.57,70.23],[-96.43,71.26],[-94.45,71.88]]],[[[-23.93,72.88],[-22.02,72.50],[-24.39,72.64],[-23.93,72.88]]],[[[-23.23,73.07],[-22.25,72.97],[-24.52,72.90],[-23.23,73.07]]],[[[-114.19,73.30],[-114.45,72.63],[-111.21,72.72],[-111.85,72.38],[-109.78,72.43],[-110.71,72.94],[-110.07,72.99],[-107.74,71.61],[-107.25,71.80],[-108.16,73.00],[-106.56,73.21],[-104.02,70.78],[-100.92,70.01],[-103.27,69.68],[-101.85,69.03],[-102.91,68.80],[-106.92,69.37],[-112.89,68.47],[-117.09,69.70],[-111.93,70.26],[-112.39,70.51],[-117.73,70.66],[-118.27,70.87],[-115.20,71.48],[-118.83,71.66],[-118.12,72.64],[-114.19,73.30]]],[[[-24.00,73.36],[-23.23,73.25],[-24.97,73.32],[-23.08,73.17],[-25.57,73.14],[-24.00,73.36]]],[[[55.30,73.33],[56.43,73.23],[55.11,72.45],[55.62,71.68],[57.63,70.72],[53.30,70.86],[53.78,71.08],[51.41,71.76],[53.43,73.24],[55.30,73.33]]],[[[-86.55,73.85],[-85.27,73.81],[-86.61,72.89],[-86.32,71.96],[-84.88,71.34],[-86.39,71.05],[-84.69,71.21],[-85.74,71.94],[-84.36,72.05],[-85.67,72.90],[-83.95,72.75],[-85.11,73.03],[-81.87,73.72],[-80.27,72.77],[-81.20,72.29],[-80.45,72.03],[-78.04,71.78],[-78.42,72.11],[-77.29,72.18],[-78.53,72.42],[-76.68,72.69],[-75.15,72.42],[-75.87,71.72],[-74.31,72.08],[-75.35,71.70],[-75.07,71.20],[-71.41,71.45],[-72.32,70.89],[-70.86,71.10],[-71.53,70.03],[-68.73,70.65],[-70.11,70.05],[-67.16,69.82],[-69.79,69.56],[-66.73,69.30],[-69.20,69.30],[-67.79,68.79],[-68.90,68.60],[-61.30,66.67],[-63.94,65.10],[-65.45,65.67],[-64.51,66.29],[-68.82,66.20],[-64.54,63.68],[-64.97,62.67],[-68.88,63.74],[-66.16,62.31],[-66.43,61.88],[-71.68,63.17],[-74.74,64.85],[-77.54,64.31],[-78.06,64.99],[-77.08,65.41],[-73.77,65.52],[-73.90,66.37],[-72.48,67.59],[-74.00,68.73],[-76.53,68.67],[-75.65,69.08],[-78.86,70.45],[-79.43,69.88],[-82.84,70.25],[-81.73,69.95],[-82.25,69.80],[-89.36,70.81],[-87.35,70.94],[-89.81,71.32],[-89.21,73.13],[-86.55,73.85]]],[[[-99.83,73.89],[-97.06,73.77],[-98.18,73.11],[-96.53,72.22],[-98.50,71.30],[-102.61,72.66],[-100.31,72.80],[-99.99,73.19],[-101.56,73.44],[-99.83,73.89]]],[[[-20.94,74.43],[-20.44,74.35],[-21.66,74.17],[-20.94,74.43]]],[[[-121.58,74.55],[-115.49,73.60],[-122.72,71.11],[-125.56,71.97],[-123.91,73.69],[-124.75,74.31],[-121.58,74.55]]],[[[139.10,76.09],[145.27,75.58],[143.84,75.05],[142.00,75.66],[143.55,75.01],[139.01,74.65],[136.94,75.26],[139.10,76.09]]],[[[-98.40,76.66],[-97.56,75.14],[-102.63,75.49],[-100.98,75.79],[-101.84,76.22],[-101.37,76.41],[-99.86,75.90],[-99.41,76.16],[-100.67,76.38],[-98.40,76.66]]],[[[-108.66,76.82],[-106.92,75.67],[-105.51,75.89],[-106.38,75.02],[-113.02,74.39],[-114.19,74.57],[-111.02,75.17],[-117.51,75.20],[-115.02,75.69],[-117.19,75.57],[-114.45,76.50],[-108.93,75.47],[-110.38,76.38],[-108.66,76.82]]],[[[68.15,76.96],[68.67,76.88],[67.91,76.25],[58.18,74.58],[58.65,74.34],[56.76,73.36],[53.76,73.72],[59.13,75.86],[68.15,76.96]]],[[[-95.23,77.01],[-89.29,76.30],[-91.23,76.22],[-89.14,75.52],[-79.50,75.39],[-81.97,74.47],[-91.81,74.72],[-93.00,76.28],[-96.96,76.73],[-95.23,77.01]]],[[[104.32,77.72],[106.11,77.40],[104.48,77.12],[107.59,76.50],[111.55,76.68],[113.61,75.86],[112.55,75.85],[113.53,75.50],[113.14,75.11],[105.35,72.83],[110.30,74.01],[113.27,73.75],[113.79,72.62],[113.23,72.73],[113.91,73.53],[115.41,73.71],[122.42,72.87],[124.30,73.77],[129.44,73.02],[127.96,72.66],[129.56,72.23],[127.85,72.42],[131.22,70.75],[133.06,71.97],[138.03,71.13],[139.83,71.49],[139.51,72.21],[141.07,72.57],[140.64,72.84],[144.30,72.64],[146.59,72.30],[145.65,72.25],[145.82,71.74],[149.61,72.14],[150.06,71.92],[148.97,71.79],[152.50,70.84],[158.88,70.89],[160.71,69.66],[161.27,68.83],[160.75,68.56],[162.29,69.65],[168.03,69.72],[170.49,68.80],[170.95,69.04],[170.18,69.58],[171.03,70.08],[176.50,69.75],[179.95,68.99],[180,65.06],[174.44,64.69],[177.12,64.71],[179.29,63.21],[179.14,62.49],[172.82,61.46],[170.16,59.95],[168.23,60.58],[163.45,59.86],[162.04,58.20],[163.32,57.70],[162.78,56.92],[163.35,56.19],[162.16,56.13],[162.13,54.77],[160.05,54.17],[160.02,53.21],[156.71,50.88],[155.55,55.28],[155.92,56.58],[156.85,57.72],[163.61,60.86],[164.12,62.24],[165.62,62.44],[163.58,62.57],[160.58,60.72],[159.21,61.91],[157.02,61.65],[154.08,59.06],[151.50,58.86],[151.58,59.50],[149.43,59.73],[142.89,59.30],[135.53,55.08],[138.55,53.98],[138.25,53.57],[139.64,54.26],[141.42,53.17],[140.17,48.46],[134.97,43.45],[131.39,42.94],[127.56,39.78],[129.41,37.03],[129.11,35.13],[126.33,34.57],[126.59,37.52],[124.79,38.09],[125.50,38.68],[125.09,39.60],[123.60,39.81],[121.28,38.78],[122.06,40.73],[117.58,38.81],[119.44,37.12],[120.78,37.82],[122.45,37.41],[119.22,35.06],[121.76,31.99],[119.84,32.29],[121.95,30.98],[120.47,30.40],[121.98,29.26],[119.59,26.79],[119.57,25.53],[116.11,22.83],[114.27,22.32],[113.63,23.03],[113.27,22.13],[110.36,21.42],[110.04,20.30],[109.59,21.74],[108.85,21.80],[105.96,19.93],[105.87,18.51],[108.91,15.05],[109.16,11.61],[106.98,10.69],[104.85,8.56],[104.73,10.23],[100.08,13.42],[99.32,9.39],[100.76,6.98],[103.25,5.13],[104.28,1.51],[101.31,2.83],[100.29,6.11],[98.24,8.40],[98.60,12.91],[97.65,16.27],[97.10,17.13],[95.52,15.80],[94.34,16.00],[93.80,19.68],[90.60,23.44],[90.30,21.98],[88.55,21.55],[87.95,22.35],[86.39,19.98],[80.20,15.51],[79.86,10.37],[77.31,8.12],[73.37,16.33],[72.92,22.25],[71.78,21.04],[70.33,20.92],[69.15,22.04],[70.37,22.90],[68.86,23.01],[66.59,25.33],[58.04,25.57],[56.86,27.02],[53.92,26.71],[51.58,27.84],[50.14,29.93],[48.11,30.04],[47.70,29.36],[50.14,26.68],[50.76,24.73],[51.21,26.13],[51.56,24.25],[54.01,24.11],[56.33,26.32],[56.80,24.30],[59.80,22.53],[57.83,20.07],[57.83,19.02],[54.94,16.98],[43.99,12.61],[43.24,13.21],[42.71,16.73],[39.24,21.04],[38.38,23.83],[34.77,28.09],[34.89,29.17],[34.25,27.80],[32.69,29.69],[39.29,15.92],[43.25,12.53],[42.53,11.50],[44.62,10.39],[51.12,11.87],[51.41,10.44],[47.94,4.45],[40.34,-2.59],[39.20,-4.87],[38.85,-6.34],[40.60,-10.82],[40.76,-14.96],[34.93,-19.82],[35.48,-24.03],[32.87,-25.54],[32.45,-28.30],[27.10,-33.51],[19.89,-34.76],[18.38,-34.26],[18.29,-32.02],[15.23,-27.02],[14.43,-22.39],[11.84,-18.14],[11.78,-15.97],[13.81,-11.29],[12.81,-6.03],[8.71,-0.66],[9.77,0.04],[9.71,4.09],[8.48,4.74],[6.09,4.27],[5.63,5.54],[3.87,6.43],[-2.06,4.73],[-4.12,5.30],[-7.59,4.34],[-9.06,5.01],[-12.88,7.85],[-15.13,11.70],[-16.53,12.24],[-15.58,12.55],[-16.62,12.66],[-15.78,13.43],[-17.26,14.70],[-16.03,18.14],[-16.81,22.13],[-14.49,26.13],[-10.22,29.33],[-8.99,32.79],[-6.73,34.16],[-5.63,35.83],[-2.15,35.10],[1.11,36.48],[10.07,37.24],[11.05,35.61],[10.44,33.65],[14.91,32.44],[18.76,30.38],[19.74,30.51],[20.04,32.14],[21.60,32.93],[28.82,30.92],[30.97,31.58],[33.48,31.13],[34.74,32.03],[35.91,36.44],[27.67,36.67],[28.11,36.93],[26.32,38.23],[26.97,38.84],[26.16,39.96],[33.16,41.95],[40.30,40.96],[41.64,42.21],[36.70,45.10],[39.26,47.00],[35.77,46.60],[34.87,45.92],[36.34,45.45],[36.04,45.04],[34.13,44.44],[32.66,45.32],[33.65,45.87],[32.00,46.89],[31.05,46.61],[27.54,42.56],[29.09,41.24],[26.32,40.11],[26.66,40.51],[25.14,40.95],[23.34,40.22],[23.74,39.93],[22.86,40.44],[23.34,39.19],[22.54,38.88],[24.08,37.75],[23.09,37.91],[23.13,36.55],[21.12,37.83],[22.88,37.93],[22.64,38.38],[21.14,38.33],[19.38,40.29],[19.59,41.79],[13.25,45.75],[12.27,45.46],[12.63,44.03],[18.37,40.33],[18.38,39.82],[16.97,40.49],[17.11,39.26],[16.12,38.00],[15.77,39.89],[8.72,44.42],[6.45,43.15],[3.13,43.12],[2.85,41.69],[0.82,40.89],[-0.19,39.70],[0.15,38.83],[-2.05,36.81],[-5.44,36.05],[-6.74,37.10],[-8.83,37.05],[-9.35,39.19],[-8.85,43.32],[-1.66,43.39],[-0.68,45.07],[-2.51,47.52],[-4.77,48.45],[-1.79,48.61],[-1.39,49.71],[0.09,49.38],[1.97,51.00],[4.22,51.36],[3.86,51.81],[5.85,53.36],[9.47,53.70],[8.12,56.55],[9.58,56.99],[8.60,56.84],[10.27,57.62],[10.09,56.70],[10.78,56.53],[9.45,55.04],[11.17,54.01],[12.81,54.45],[14.18,53.73],[13.77,54.02],[18.31,54.83],[19.37,54.37],[21.24,55.44],[21.51,57.38],[24.37,57.23],[23.48,59.17],[29.80,59.94],[28.32,60.62],[23.08,59.82],[21.61,60.48],[21.36,62.86],[25.39,64.95],[24.85,65.65],[22.32,65.83],[20.67,63.84],[17.72,62.99],[17.05,61.58],[17.33,60.62],[18.78,60.01],[18.05,59.39],[18.61,59.37],[16.57,58.64],[15.87,56.10],[13.28,55.34],[10.62,59.63],[7.39,58.01],[5.47,58.75],[6.62,59.05],[5.20,59.42],[7.03,60.47],[5.54,60.16],[5.00,61.03],[7.60,61.19],[4.99,61.63],[11.03,63.71],[11.46,63.99],[9.58,63.67],[12.71,65.18],[14.04,67.05],[15.50,67.07],[14.41,67.24],[16.00,68.01],[15.38,68.02],[16.43,67.80],[16.26,68.32],[17.81,68.38],[16.73,68.45],[19.55,69.80],[22.05,69.74],[21.63,70.09],[25.06,70.95],[25.65,70.44],[26.61,70.94],[26.52,70.44],[28.14,71.07],[27.84,70.48],[30.81,70.41],[28.94,70.15],[30.11,69.70],[32.91,69.78],[32.41,69.64],[33.42,69.44],[33.06,69.08],[35.80,69.19],[40.96,67.72],[41.04,66.74],[38.95,66.10],[32.07,67.14],[34.89,65.80],[34.83,64.53],[37.26,63.84],[37.79,64.41],[36.43,64.91],[36.90,65.15],[40.35,64.56],[39.72,65.38],[40.79,65.99],[43.98,66.10],[44.41,68.06],[43.27,68.65],[46.35,68.21],[46.72,67.84],[45.09,67.56],[45.96,66.86],[53.87,68.97],[54.52,69.00],[53.42,68.36],[58.87,69.00],[59.67,68.33],[60.93,69.07],[60.68,69.80],[68.26,68.24],[69.10,68.87],[67.10,69.69],[66.90,71.28],[69.46,72.97],[71.55,72.90],[72.87,72.28],[72.02,71.57],[72.85,68.79],[73.53,68.58],[70.93,66.58],[69.39,66.83],[72.26,66.29],[74.80,67.88],[74.92,68.81],[76.58,68.97],[77.07,67.79],[78.74,67.59],[77.61,67.73],[77.28,68.97],[73.77,69.15],[74.19,70.43],[73.03,71.40],[75.11,72.34],[74.74,72.80],[75.62,72.41],[75.44,71.46],[78.36,70.90],[78.88,70.92],[76.18,71.71],[78.75,72.39],[82.86,71.78],[82.19,70.38],[83.03,70.90],[83.48,70.33],[83.61,71.55],[80.32,73.18],[86.78,73.90],[85.78,73.48],[86.71,73.08],[86.25,73.27],[87.31,73.68],[86.02,74.26],[87.11,74.35],[85.74,74.63],[87.76,75.01],[87.03,75.09],[102.24,76.38],[101.03,76.52],[104.32,77.72]],[[50.95,47.05],[46.70,44.56],[50.26,40.45],[48.94,37.92],[51.90,36.58],[53.95,36.91],[52.73,40.48],[54.72,41.05],[53.68,42.14],[52.84,41.24],[52.66,42.61],[50.23,44.47],[52.90,45.31],[53.08,46.85],[50.95,47.05]]],[[[16.82,79.87],[21.39,78.86],[18.99,78.46],[16.50,76.60],[13.99,77.39],[16.86,77.81],[13.60,78.04],[17.14,78.39],[13.14,78.22],[10.89,79.47],[14.92,79.75],[16.23,78.96],[15.64,79.83],[16.82,79.87]]],[[[97.77,80.13],[97.44,79.74],[99.73,79.92],[99.14,79.31],[99.82,79.10],[93.16,79.44],[97.77,80.13]]],[[[23.14,80.38],[26.90,80.15],[23.67,79.20],[17.80,80.12],[23.14,80.38]]],[[[95.96,81.20],[97.92,80.74],[91.42,80.30],[95.96,81.20]]],[[[-92.77,81.31],[-85.30,79.42],[-90.88,78.14],[-94.27,78.96],[-90.70,79.21],[-96.61,79.88],[-94.42,79.98],[-96.32,80.26],[-92.77,81.31]]],[[[-45.98,82.64],[-44.52,82.41],[-47.36,82.53],[-45.98,82.64]]],[[[-69.68,83.11],[-61.34,82.45],[-68.94,81.66],[-66.96,81.55],[-69.92,81.18],[-64.54,81.55],[-72.41,80.21],[-70.64,80.14],[-71.94,79.70],[-77.78,79.35],[-74.79,79.24],[-78.61,79.07],[-74.63,78.58],[-78.21,78.00],[-78.28,77.37],[-82.15,77.31],[-77.77,76.66],[-80.60,76.19],[-89.41,76.49],[-86.82,77.12],[-88.22,77.85],[-84.46,77.30],[-82.35,78.06],[-83.91,77.49],[-85.47,77.87],[-84.20,78.15],[-87.12,78.12],[-86.01,78.83],[-81.47,79.04],[-84.50,79.01],[-83.44,79.02],[-86.15,79.73],[-85.89,80.33],[-80.35,79.62],[-79.75,79.70],[-83.00,80.27],[-76.56,80.84],[-78.84,80.85],[-77.19,81.37],[-85.55,80.52],[-86.74,80.60],[-82.75,81.13],[-87.70,80.64],[-89.45,80.90],[-85.18,81.23],[-89.94,81.02],[-87.28,81.48],[-91.95,81.66],[-84.60,81.89],[-86.85,82.19],[-85.05,82.47],[-79.52,81.82],[-82.71,82.38],[-69.68,83.11]]],[[[-32.20,83.61],[-26.10,83.32],[-35.14,82.93],[-21.62,82.67],[-32.56,81.88],[-21.12,81.97],[-23.60,80.68],[-19.70,81.69],[-11.74,81.55],[-20.80,80.56],[-16.12,80.45],[-20.17,80.10],[-18.93,79.26],[-21.62,77.99],[-18.25,76.94],[-22.64,76.74],[-19.38,75.54],[-22.34,75.16],[-19.12,74.50],[-22.46,74.31],[-20.36,73.89],[-20.91,73.45],[-25.41,73.81],[-24.85,73.56],[-27.60,73.16],[-21.89,71.74],[-22.42,71.58],[-21.76,70.57],[-28.62,72.13],[-25.52,71.38],[-29.03,70.47],[-26.52,70.47],[-28.25,70.14],[-22.37,70.11],[-26.84,68.63],[-32.14,68.38],[-34.67,66.43],[-39.99,65.55],[-41.14,64.96],[-40.96,63.67],[-42.90,62.70],[-42.22,61.88],[-43.20,61.35],[-42.74,60.69],[-44.20,60.60],[-43.09,60.11],[-45.11,60.10],[-44.62,60.37],[-45.82,60.56],[-45.45,61.02],[-47.94,60.84],[-50.03,62.36],[-50.05,63.22],[-51.07,63.25],[-50.57,63.64],[-51.48,63.97],[-50.48,64.15],[-51.63,64.11],[-50.02,64.45],[-50.87,65.15],[-52.03,64.19],[-51.65,64.86],[-52.51,65.19],[-50.98,65.76],[-53.15,65.86],[-50.13,66.96],[-53.45,66.10],[-52.45,66.52],[-53.64,66.91],[-53.07,67.25],[-50.41,67.17],[-53.67,67.22],[-53.12,67.59],[-50.01,67.68],[-53.33,67.59],[-52.25,67.94],[-53.33,68.15],[-50.56,67.90],[-53.07,68.28],[-50.96,68.67],[-50.27,69.76],[-54.53,70.65],[-50.56,70.33],[-52.55,71.16],[-51.42,71.43],[-52.70,71.39],[-51.65,71.69],[-53.69,72.12],[-55.28,71.38],[-55.76,71.66],[-54.55,72.03],[-55.26,71.92],[-54.83,72.98],[-58.59,75.67],[-68.38,76.08],[-71.38,77.02],[-66.50,77.27],[-72.58,78.06],[-65.97,79.10],[-63.81,80.13],[-67.51,80.26],[-61.04,81.13],[-60.53,81.91],[-56.56,81.33],[-59.42,81.97],[-54.84,82.34],[-53.57,82.12],[-53.79,81.66],[-49.61,81.64],[-50.73,81.85],[-49.65,81.88],[-50.73,82.21],[-50.26,82.48],[-44.78,81.77],[-42.74,82.25],[-45.66,82.72],[-39.75,82.39],[-46.70,83.00],[-38.49,82.81],[-39.00,82.94],[-36.93,83.14],[-38.73,83.23],[-38.25,83.39],[-32.20,83.61]]]],"type":"MultiPolygon"}
      """)
    
    let green: GeoDrawer.Color
#if canImport(AppKit)
    green = NSColor.systemGreen.cgColor
#elseif canImport(UIKit)
    green = UIColor.systemGreen.cgColor
#else
    green = GeoDrawer.Color(red: 0, green: 1, blue: 0)
#endif
    return content(for: geoJSON, color: green)
  }
}
