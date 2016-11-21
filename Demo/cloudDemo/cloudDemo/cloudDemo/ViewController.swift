//
//  ViewController.swift
//  cloudDemo
//
//  Created by justin lau on 16/11/21.
//  Copyright © 2016年 justin lau. All rights reserved.
//

import UIKit
import CloudKit

class ViewController: UIViewController {

    var record: CKRecord?
    
    
    @IBAction func btnAction(_ sender: UIButton) {
        
        let btnTitle:String! = sender.titleLabel?.text
        switch btnTitle {
        case "1":btn1Action()
        case "2":btn2Action()
        case "3":btn3action()
        case "4":break
        default:
            break
        }
        
    }
    
    
    func btn1Action(){
        
        print("1")
        let id = CKRecordID.init(recordName: "liudehua")
        let artistRecord = CKRecord.init(recordType: "Artist", recordID: id)
        artistRecord["first_name"] = "liu" as CKRecordValue?
        artistRecord["middle_name"] = "de" as CKRecordValue?
        artistRecord["last_name"] = "hua" as CKRecordValue?
        record = artistRecord
    }

    
    func btn2Action(){
        print("2")
        
        guard let record = record else {
            return
        }
        
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        
        publicDatabase.save(record, completionHandler: {
            
            (result, error) in
            
            
            if error != nil {
                print(error!)
            }else {
                print(result!)
            }
            
        })
    }
    
    
    func btn3action() {
        CKContainer.default().accountStatus { (status, error) in
            
            switch status{
            case .noAccount:
                
                let alertView = UIAlertController.init(title: "title", message: "message", preferredStyle: .alert)
                alertView.addAction(UIAlertAction.init(title: "cancle", style: .cancel, handler: nil))
                self.present(alertView, animated: true, completion: nil)
                
            case .restricted: break
            case .available: break
            case .couldNotDetermine: break
            
            }
            
        }
    }

}

