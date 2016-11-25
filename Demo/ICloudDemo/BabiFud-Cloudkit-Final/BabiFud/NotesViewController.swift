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

final class NotesViewController: UIViewController {

  // MARK: - Properties
  var establishment: Establishment!

  // MARK: - IBOutlet
  @IBOutlet var textView: UITextView!

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
  }
  
  func keyboardWillShow(_ note: Notification) {
    let userInfo: NSDictionary = (note as NSNotification).userInfo! as NSDictionary
    let keyboardFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue
    let keyboardFrame = keyboardFrameValue.cgRectValue as CGRect
    var contentInsets = textView.contentInset
    contentInsets.bottom = keyboardFrame.height
    
    textView.contentInset = contentInsets
    textView.scrollIndicatorInsets = contentInsets
  }
  
  func keyboardWillHide(_ note: Notification) {
    var contentInsets = textView.contentInset
    contentInsets.bottom = 0.0
    textView.contentInset = contentInsets
    textView.scrollIndicatorInsets = contentInsets
  }
}

// MARK: - IBActions
extension NotesViewController {

  @IBAction func save(_ sender: AnyObject) {
    let noteText = textView.text
    if let noteText = noteText {
      Model.sharedInstance.addNote(noteText, establishment: establishment) { [unowned self] error in
        
        guard error != nil else {
          let viewControllers = self.navigationController?.viewControllers
          let detailController = viewControllers![0] as! DetailViewController
          detailController.noteTextView.text = noteText
          _ = self.navigationController?.popViewController(animated: true)
          return
        }
        let alertController = UIAlertController(title: "Error saving note",
                                                message: error?.localizedDescription,
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
      }
    
    }
  }
}
