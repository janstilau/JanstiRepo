/*
* Copyright (c) 2016 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import MapKit

final class MapViewController: UIViewController {

  // MARK: - Properties
  fileprivate let pinIdentifier = "Pin"

  // MARK: - IBOutlets
  @IBOutlet var mapView: MKMapView!
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {

  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    let region = mapView.region

    let cla = round(region.center.latitude * 100.0) / 100.0
    let clo = round(region.center.longitude * 100.0) / 100.0
    let center = CLLocation(latitude:  cla, longitude: clo)

    // This works for the US hemisphere.
    let upperLeft = CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta,
                                               region.center.longitude + region.span.longitudeDelta)
    let corner = CLLocation(latitude:  upperLeft.latitude,
                            longitude: upperLeft.longitude)
    let distance = center.distance(from: corner)
    let mapCenter = CLLocation(coordinate: mapView.centerCoordinate, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())

    Model.sharedInstance.fetchEstablishments(mapCenter, radiusInMeters: distance) { [weak self] results, error in
      guard let error = error else {
        mapView.removeAnnotations(mapView.annotations);
        if let results = results {
          mapView.addAnnotations(results)
        }
        return
      }

      let alertController = UIAlertController(title: "Error Loading Establishments",
                                    message: error.localizedDescription,
                                    preferredStyle: .alert)

      alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))

      self?.present(alertController, animated: true, completion: nil)
    }
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: pinIdentifier)

    if pinView == nil {
      pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinIdentifier)
      pinView?.canShowCallout = true
    }

    pinView?.annotation = annotation

    guard let establishment = annotation as? Establishment else { return pinView }

    establishment.loadCoverPhoto { photo in
      guard let photo = photo else { return }

      UIGraphicsBeginImageContext(CGSize(width: 30, height: 30))
      photo.draw(in: CGRect(x: 0, y: 0, width: 30, height: 30))
      let smallImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      let imView = UIImageView(image: smallImage)
      pinView!.leftCalloutAccessoryView = imView
    }

    return pinView
  }
}
