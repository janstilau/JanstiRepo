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
import CoreLocation

final class MasterViewController: UITableViewController {

  // MARK: - Properties
  let model: Model = Model.sharedInstance

  var detailViewController: DetailViewController?
  var locationManager: CLLocationManager!

  // MARK: - View Life Cycle
  override func awakeFromNib() {
    super.awakeFromNib()

    guard case(.pad) = traitCollection.userInterfaceIdiom  else { return }

    clearsSelectionOnViewWillAppear = false
    preferredContentSize = CGSize(width: 320.0, height: 600.0)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setupLocationManager()

    model.delegate = self
    model.refresh()

    // Set up a refresh control.
    refreshControl = UIRefreshControl()
    refreshControl?.addTarget(model, action: #selector(Model.refresh), for: .valueChanged)

    guard let splitViewController = splitViewController,
      let navigationController = splitViewController.viewControllers.last as? UINavigationController,
      let detailViewController = navigationController.topViewController as? DetailViewController else {
        return
    }

    self.detailViewController = detailViewController
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == "showDetail",
      let indexPath = tableView.indexPathForSelectedRow,
      let navigationController = segue.destination as? UINavigationController,
      let detailController = navigationController.topViewController as? DetailViewController else {
        return
    }

    let detailItem = Model.sharedInstance.items[(indexPath as NSIndexPath).row]
    detailController.detailItem = detailItem
  }
}

// MARK: - UITableViewDataSource
extension MasterViewController {

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return Model.sharedInstance.items.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! EstablishmentCell
    let object = Model.sharedInstance.items[(indexPath as NSIndexPath).row]
    cell.titleLabel.text = object.name

    object.fetchRating { (rating: Double, isUser: Bool) in
      DispatchQueue.main.async {
        cell.starRating.rating = Float(rating)
        cell.starRating.emptyColor = isUser ? .yellow : .white
        cell.starRating.solidColor = isUser ? .yellow : .white
      }
    }

    var badges: [UIImage] = object.changingTable().images()
    badges.append(contentsOf: object.seatingType().images())
    cell.badgeView.setBadges(badges)

    object.loadCoverPhoto { image in
      DispatchQueue.main.async {
        cell.coverPhotoView.image = image
      }
    }

    return cell
  }
}

// MARK: - UITableViewDelegate
extension MasterViewController {

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard case(.pad) = traitCollection.userInterfaceIdiom else { return }

    let detailItem = Model.sharedInstance.items[(indexPath as NSIndexPath).row]
    detailViewController?.detailItem = detailItem
  }
}

// MARK: - ModelDelegate
extension MasterViewController: ModelDelegate {

  func modelUpdated() {
    // Replace this stub.
  }

  func errorUpdating(_ error: NSError) {
    // Replace this stub.
  }
}

// MARK: - CLLocationManagerDelegate
extension MasterViewController: CLLocationManagerDelegate {

  func setupLocationManager() {
    locationManager = CLLocationManager()
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

    // Only look at locations within a 0.5 km radius.
    locationManager.distanceFilter = 500.0
    locationManager.delegate = self

    CLLocationManager.authorizationStatus()
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)  {
    switch status {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      manager.startUpdatingLocation()
    default:
      // Do nothing.
      print("Other status")
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }

    model.fetchEstablishments(location, radiusInMeters: 3000)
  }
}

