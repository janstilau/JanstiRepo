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
        case "3":btn3Action()
        case "4":btn4Action()
        case "5":btn5Action()
        case "6":btn6Action()
        case "7":btn7Action()
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
    
    
    func btn3Action() {
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
    
    func btn4Action() {
        
        let container = CKContainer.default()
        let publicDatabase = container.publicCloudDatabase
        
        let localDataPath = Bundle.main.path(forResource: "localDevData", ofType: "plist")
        let dictData = NSArray.init(contentsOfFile: localDataPath!)
        let dictArray = dictData as! Array<Dictionary<String, String>>
        for dict in dictArray{
            
            var name: String = ""
            for value in dict.values{
                name += value
            }
            
            let id = CKRecordID.init(recordName: name)
            let artistRecord = CKRecord.init(recordType: "Artist", recordID: id)
            for (key,value) in dict {
                artistRecord[key] = value as CKRecordValue?
            }
            publicDatabase.save(artistRecord, completionHandler: { (result, error) in
                if error != nil {
                    print(error!)
                }else {
                    print(result!)
                }
            })
        }
    }
    
    
    func btn5Action(){
        let database = CKContainer.default().publicCloudDatabase
        let artistId = CKRecordID.init(recordName: "liudehua")
        database.fetch(withRecordID: artistId, completionHandler: {(result, error) -> Void in
            
            if error != nil {
                print(error!)
            }else {
                result!["first_name"] = "zhou" as CKRecordValue?
                database .save(result!, completionHandler: { (saveRecord, saveError) in
                    if saveError != nil {
                        print(saveError!)
                    }else {
                        print(saveRecord!)
                    }
                })
            }
            })
    }
    
    func btn6Action(){
        
        let dataBase = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate.init(format: "score != 1000")
        let query = CKQuery.init(recordType: "Artist", predicate: predicate)
        
        dataBase.perform(query, inZoneWith: nil, completionHandler: {
            
            (array,error) in
            if error != nil {
                
            }else {
                if let resultArray = array{
                    for value in resultArray {
                        value["score"] = arc4random_uniform(100) as CKRecordValue?
                        
                        let fileURl = Bundle.main.url(forResource: "img", withExtension: "png")
                        let asset = CKAsset.init(fileURL: fileURl!)
                        value["image"] = asset
                        dataBase.save(value, completionHandler: { (saveResult, saveError) in
                            if error != nil {
                                print(saveError!)
                            }else {
                                print(saveResult!)
                            }
                        })
                    }
                }
            }
        
        })
        
    }
    
    func btn7Action(){
        let database = CKContainer.default().publicCloudDatabase
        let recordId = CKRecordID.init(recordName: "5M5F5L")
        let artistRef = CKReference.init(recordID: recordId, action: CKReferenceAction.none)
        let id = CKRecordID.init(recordName: "1ArtWork")
        let artWorkRecord = CKRecord.init(recordType: "ArtWork", recordID: id)
        artWorkRecord["name"] = "蒙娜丽煞" as CKRecordValue?
        artWorkRecord["artist"] = artistRef as CKRecordValue?
        
        database.save(artWorkRecord, completionHandler: { (saveResult, saveError) in
            if saveError != nil {
                print(saveError!)
            }else {
                print(saveResult!)
            }
        })
        

    }

}

