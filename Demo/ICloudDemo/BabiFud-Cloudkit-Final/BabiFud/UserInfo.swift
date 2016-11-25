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

class UserInfo {
  
  // MARK: - Properties
  let container: CKContainer
  var userRecordID: CKRecordID!
  var contacts: [AnyObject] = []
  
  // MARK: - Initializers
  init (container: CKContainer) {
    self.container = container;
  }

  func loggedInToICloud(_ completion: (_ accountStatus: CKAccountStatus, _ error: NSError?) -> ()) {
    // Capability not yet implemented.
    completion(.couldNotDetermine, nil)
  }

  func userID(_ completion: @escaping (_ userRecordID: CKRecordID?, _ error: NSError?)->()) {

    guard userRecordID != nil else {
      container.fetchUserRecordID() { recordID, error in

        if recordID != nil {
          self.userRecordID = recordID
        }
        completion(recordID, error as NSError?)
      }
      return
    }
    completion(userRecordID, nil)
  }

  func userInfo(_ recordID: CKRecordID!, completion:(_ userInfo: CKDiscoveredUserInfo?, _ error: NSError?)->()) {
    // Capability not yet implemented.
    completion(nil, nil)
  }

  func requestDiscoverability(_ completion: (_ discoverable: Bool) -> ()) {
    // Capability not yet implemented.
    completion(false)
  }

  func userInfo(_ completion: @escaping (_ userInfo: CKDiscoveredUserInfo?, _ error: NSError?)->()) {

    requestDiscoverability() { discoverable in
      self.userID() { [weak self] recordID, error in

        guard error != nil else {
          self?.userInfo(recordID, completion: completion)
          return
        }
        completion(nil, error)
      }
    }
  }

  func findContacts(_ completion: (_ userInfos:[AnyObject]?, _ error: NSError?)->()) {
    completion([CKRecordID](), nil)
  }
}
