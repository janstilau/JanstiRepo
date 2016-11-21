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
import UIWidgets
import CloudKit

final class DetailViewController: UITableViewController {

  // MARK: - Properties
  var detailItem: Establishment! {
    didSet {
      if let _ = presentedViewController {
        dismiss(animated: true, completion: nil)
      }
    }
  }

  // MARK: - IBOutlet
  @IBOutlet var coverView: UIImageView!
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var starRating: StarRatingControl!
  @IBOutlet var kidsMenuButton: CheckedButton!
  @IBOutlet var healthyChoiceButton: CheckedButton!
  @IBOutlet var womensRoomButton: UIButton!
  @IBOutlet var mensRoomButton: UIButton!
  @IBOutlet var boosterButton: UIButton!
  @IBOutlet var highchairButton: UIButton!
  @IBOutlet var addPhotoButton: UIButton!
  @IBOutlet var photoScrollView: UIScrollView!
  @IBOutlet var noteTextView: UITextView!

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    coverView.clipsToBounds = true
    coverView.layer.cornerRadius = 10.0

    // Add star rating block here.
  }

  override func viewWillAppear(_ animated: Bool)  {
    super.viewWillAppear(animated)
    configureView()
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any!) {
    guard segue.identifier == "EditNote",
      let noteController = segue.destination as? NotesViewController else {
        return
    }

    noteController.establishment = detailItem
  }

  func configureView() {
    // Update the user interface for the detail item.
    guard let detail: Establishment = detailItem else { return }

    title = detail.name

    detail.loadCoverPhoto() { image in
      DispatchQueue.main.async {
        self.coverView.image = image
      }
    }
    
    titleLabel.text = detail.name
    
    starRating.maxRating = 5
    starRating.isEnabled = false
    
    Model.sharedInstance.userInfo.loggedInToICloud() {
      accountStatus, error in
      let enabled = accountStatus == .available || accountStatus == .couldNotDetermine
      self.starRating.isEnabled = enabled
      self.healthyChoiceButton.isEnabled = enabled
      self.kidsMenuButton.isEnabled = enabled
      self.mensRoomButton.isEnabled = enabled
      self.womensRoomButton.isEnabled = enabled
      self.boosterButton.isEnabled = enabled
      self.highchairButton.isEnabled = enabled
      self.addPhotoButton.isEnabled = enabled
    }
    
    kidsMenuButton.checked = detailItem.kidsMenu
    healthyChoiceButton.checked = detailItem.healthyChoice
    womensRoomButton.isSelected = (detailItem.changingTable() & ChangingTableLocation.Womens).boolValue
    mensRoomButton.isSelected = (detailItem.changingTable() & ChangingTableLocation.Mens).boolValue
    highchairButton.isSelected = (detailItem.seatingType() & SeatingType.HighChair).boolValue
    boosterButton.isSelected = (detailItem.seatingType() & SeatingType.Booster).boolValue
    
    detail.fetchRating() { rating, isUser in
      DispatchQueue.main.async {
        self.starRating.maxRating = 5
        self.starRating.rating = Float(rating)
        self.starRating.setNeedsDisplay()
        
        self.starRating.emptyColor = isUser ? .yellow : .white
        self.starRating.solidColor = isUser ? .yellow : .white
      }
    }
    
    detail.fetchPhotos() { assets in
      guard let assets = assets else { return }
      
      var x = 10
      for record in assets {
        guard let asset = record["Photo"] as? CKAsset,
          let photoUserRef = record["User"] as? CKReference,
          let image = UIImage(contentsOfFile: asset.fileURL.path) else {
            continue
        }

        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(x: x, y: 0, width: 60, height: 60)
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        x += 70

        imageView.layer.borderWidth = 0.0

        let photoUserID = photoUserRef.recordID
        let contactList = Model.sharedInstance.userInfo.contacts
        let contacts = contactList.filter { $0.userRecordID == photoUserID }
        
        if contacts.count > 0 {
          imageView.layer.borderWidth = 1.0
          imageView.layer.borderColor = UIColor.green.cgColor
        }
        
        DispatchQueue.main.async {
          self.photoScrollView.addSubview(imageView)
        }
      }
    }
    
    detail.fetchNote() { note in
      guard let noteText = note else { return }

      print("Establishment record note = \(note)")

      DispatchQueue.main.async {
        self.noteTextView.text = noteText
      }
    }
  }

  func saveRating(_ rating: NSNumber) {
    // Capability not yet implemented.
  }
}

// MARK: - IBActions
extension DetailViewController {

  @IBAction func addPhoto(_ sender: AnyObject) {
    let imagePicker = UIImagePickerController()
    imagePicker.delegate = self
    imagePicker.sourceType = .savedPhotosAlbum
    present(imagePicker, animated: true, completion: nil)
  }
}

// MARK: - UISplitViewControllerDelegate
extension DetailViewController: UISplitViewControllerDelegate {
  
  func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewControllerDisplayMode) {
    switch displayMode {
    case .primaryHidden:
      let barButtonItem = svc.displayModeButtonItem
      barButtonItem.title = NSLocalizedString("Places", comment: "Places")
      navigationItem.setLeftBarButton(barButtonItem, animated: true)
    case.allVisible:
      navigationItem.setLeftBarButton(nil, animated: true)
    default:
      break
    }
  }
  
  func splitViewController(_ splitController: UISplitViewController,
                           collapseSecondary secondaryViewController: UIViewController,
                           onto primaryViewController: UIViewController) -> Bool {
    // Return true to indicate that the collapse has been handled by doing nothing.  The secondary controller will be discarded.
    return true
  }
}

// MARK: - UINavigationControllerDelegate
extension DetailViewController: UINavigationControllerDelegate {
}

// MARK: - UIImagePickerControllerDelegate
extension DetailViewController: UIImagePickerControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    dismiss(animated: true, completion: nil)

    guard let selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage else { return }
    
    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
      self.addPhotoToEstablishment(selectedImage)
    }
  }
}

// MARK: - Image Picking
extension DetailViewController {

  func addNewPhotoToScrollView(_ photo:UIImage) {
    let newImView = UIImageView(image: photo)
    let offset = detailItem.assetCount * 70 + 10
    let frame = CGRect(x: offset, y: 0, width: 60, height: 60)

    newImView.frame = frame
    newImView.clipsToBounds = true
    newImView.layer.cornerRadius = 8

    DispatchQueue.main.async {
      self.photoScrollView.addSubview(newImView)
      self.photoScrollView.contentSize = CGSize(width: frame.maxX, height: frame.height)
    }
  }

  func addPhotoToEstablishment(_ photo: UIImage) {
    // Capability not yet implemented.
  }
}
