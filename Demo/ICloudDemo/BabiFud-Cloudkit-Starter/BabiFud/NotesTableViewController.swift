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

final class NotesTableViewController: UITableViewController {

  // MARK: - Properties
  var notes: [CKRecord] = []

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    Model.sharedInstance.fetchNotes { (notes: [CKRecord]?, error: NSError?) in
      guard error == nil else { return }
      
      self.notes = notes!
      DispatchQueue.main.async {
        self.tableView.reloadData()
      }
    }
  }
}

// MARK: - UITableViewDataSource
extension NotesTableViewController {

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return notes.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "NotesCell", for: indexPath) as! NotesCell
    let record: CKRecord = notes[(indexPath as NSIndexPath).row] 
    cell.notesLabel.text = record["Note"] as? String

    guard let establishmentRef = record["Establishment"] as? CKReference,
      let establishment = Model.sharedInstance.establishment(establishmentRef) else {
        cell.thumbImageView.image = nil
        cell.titleLabel.text = "???"
        return cell
    }

    cell.titleLabel.text = establishment.name
    establishment.loadCoverPhoto() { photo in
      DispatchQueue.main.async {
        cell.thumbImageView.image = photo
      }
    }

    return cell
  }
}
