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
import CloudKit

final class SettingsViewController: UITableViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateLogin()
  }

  func updateLogin() {
    let indexPath = IndexPath(row: 0, section: 0)
    guard let cell = tableView.cellForRow(at: indexPath) else { return }

    Model.sharedInstance.userInfo.loggedInToICloud { accountStatus, error in
      var text  = "Could not determine iCloud account status."

      defer {
        DispatchQueue.main.async {
          cell.textLabel?.text = text
          self.tableView.reloadData()
        }
      }

      guard case(.available) = accountStatus else { return }

      text = "Logged in to iCloud"
      Model.sharedInstance.userInfo.userInfo() { userInfo, error in
        guard let userInfo = userInfo,
          let displayContact = userInfo.displayContact else {
            return
        }

        DispatchQueue.main.async {
          let nameText = "Logged in as \(displayContact.givenName) \(displayContact.familyName)"
          cell.textLabel?.text = nameText
        }
      }
    }
  }
}
