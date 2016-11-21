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

import Foundation
import CloudKit
import MapKit

class Establishment: NSObject, MKAnnotation {

  // MARK: - Properties
  var record: CKRecord!
  var name: String!
  var location: CLLocation!
  weak var database: CKDatabase!
  var assetCount = 0

  var healthyChoice: Bool {
    guard let hasHealthyChoice = record["HealthyOption"] as? NSNumber else { return false }
    return hasHealthyChoice.boolValue
  }

  var kidsMenu: Bool {
    guard let hasKidsMenu = record["KidsMenu"] as? NSNumber else { return false }
    return hasKidsMenu.boolValue
  }

  // MARK: - Map Annotation Properties
  var coordinate: CLLocationCoordinate2D {
    return location.coordinate
  }

  var title: String? {
    return name
  }

  // MARK: - Initializers
  init(record: CKRecord, database: CKDatabase) {
    self.record = record
    self.database = database

    self.name = record["Name"] as? String
    self.location = record["Location"] as? CLLocation
  }

  func fetchRating(_ completion: @escaping (_ rating: Double, _ isUser: Bool) -> ()) {
    Model.sharedInstance.userInfo.userID() { [weak self] userRecord, error in
      self?.fetchRating(userRecord, completion: completion)
    }
  }
  
  func fetchRating(_ userRecord: CKRecordID!, completion: (_ rating: Double, _ isUser: Bool) -> ()) {
    // Capability not yet implemented.
    completion(0, false)
  }

  func fetchNote(_ completion: @escaping (_ note: String?) -> ()) {
    Model.sharedInstance.fetchNote(self) { note, error in
      completion(note)
    }
  }
  
  func fetchPhotos(_ completion: @escaping (_ assets: [CKRecord]?) -> ()) {
    let predicate = NSPredicate(format: "Establishment == %@", record)
    let query = CKQuery(recordType: "EstablishmentPhoto", predicate: predicate)

    // Intermediate Extension Point - with cursors
    database.perform(query, inZoneWith: nil) { [weak self] results, error in
      defer {
        completion(results)
      }

      guard error == nil,
        let results = results else {
          return
      }

      self?.assetCount = results.count
    }
  }
  
  func changingTable() -> ChangingTableLocation {
    let changingTable = record["ChangingTable"] as? NSNumber
    var val: UInt = 0
    guard let changingTableNum = changingTable else {
      return ChangingTableLocation(rawValue: val)
    }
    val = changingTableNum.uintValue
    return ChangingTableLocation(rawValue: val)
  }
  
  func seatingType() -> SeatingType {
    let seatingType = record["SeatingType"] as? NSNumber
    var val: UInt = 0
    guard let seatingTypeNum = seatingType else {
      return SeatingType(rawValue: val)
    }
    val = seatingTypeNum.uintValue
    return SeatingType(rawValue: val)
  }

  func loadCoverPhoto(completion:@escaping (_ photo: UIImage?) -> ()) {
    // Replace this stub.
    completion(nil)
  }
}
