//
//  DetailedViewController.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/24.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit

private let kUpdatedMessage = "City has been updated successfully"
private let kUnwindSegue = "unwindToMainId"

class DetailedViewController: BaseViewController {
    
    var city: City!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var cityImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        NotificationCenter.default.addObserver(self, selector: #selector(DetailedViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailedViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    
    //MARK: Private
    fileprivate func setupView() {
        cityImageView.image = city.image
        nameLabel.text = city.name
        descriptionTextView.text = city.text
    }
    
    fileprivate func shouldAnimateIndicator(_ animate: Bool) {
        if animate {
//            self.indicatorView.startAnimating()
        } else {
//            self.indicatorView.stopAnimating()
        }
        
        self.view.isUserInteractionEnabled = !animate
        self.navigationController!.navigationBar.isUserInteractionEnabled = !animate
    }
    
    func keyboardWillShow(_ notification: Notification) {
        
//        let keyboardSize = ((notification as NSNotification).userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
        
        self.scrollView.contentOffset = CGPoint.init(x: 0, y: 270)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        
        self.scrollView.contentOffset = CGPoint.init(x: 0, y: 0)
    }
    
    
    @IBAction func saveButtonDidPress(_ sender: Any) {
        view.endEditing(true)
        
        let identifier = city.identifier
        let updatedText = descriptionTextView.text!
        
        shouldAnimateIndicator(true)
        CloudKitManager.updateRecord(identifier, text: updatedText) { record, error in
            self.shouldAnimateIndicator(false)
            if let error = error {
                self.presentMessage(error.localizedDescription)
            } else if let record = record {
                self.city.text = record.value(forKey: cityText) as! String
                self.presentMessage(kUpdatedMessage)
            }
        }
    }
    
    @IBAction func removeButtonDidPress(_ sender: Any) {
        self.shouldAnimateIndicator(true)
        CloudKitManager.removeRecord(city.identifier, completion:
            { (recordId, error) in
                self.shouldAnimateIndicator(false)
                
                if let error = error {
                    self.presentMessage(error.localizedDescription)
                }else {
                    self.performSegue(withIdentifier: kUnwindSegue, sender: self)
                }
        })
    }
    
}
























