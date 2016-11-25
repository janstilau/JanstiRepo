//
//  CloudKitManager.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/23.
//  Copyright © 2016年 jansti. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

private let recordType = "Cities"




/*
 public enum CKDatabaseScope : Int {
 
 
 case `public`
 
 case `private`
 
 case shared
 }
 
 */ // 这上面,就是用到了系统保留关键字,但是这些关键字又和业务相关,所以用''进行了修饰.


// 这个工具类基本就是封装了icloud的系统方法,icloud的方法一般都有一个提交给icloud的回调,然后在回调里面,执行自己定义的block
final class CloudKitManager {
    
    fileprivate init(){
        
    }//  这里什么意思呢,let manager = CluodKitManager(), 这句话如果在别的文件里面进行书写会报错, isnot inaccessible, cause fileprivate,所以在这里添加了访问权限的设置,这样就是让在外界不能通过生成实例来访问这个方法了.
    
    static var publicCloudDatabase: CKDatabase{
        return CKContainer.default().publicCloudDatabase
    }
    
    
    // MARK: Retrieve existing records
    static func fetchAllCities(_ completion:@escaping (_ records: [City]?,_ error: NSError?) -> Void){
        let predicate = NSPredicate.init(value: true)// evalueatePrediate总是返回true
        let query = CKQuery.init(recordType: recordType, predicate: predicate)
        // 根据谓词来进行icould的查找.
        publicCloudDatabase.perform(query, inZoneWith: nil, completionHandler: {
            (records, error) in
            let cities = records?.map({ (record) -> City in
                return City.init(record: record)
            })
            
            // let cities = records?.map(City.init)这里,是这样写的,不太明白.这里有一个非常
            DispatchQueue.main.async{
                completion(cities, error as NSError?)
            }
        })
    }// 这里我们看到,所有的查找,插入,修改都要在调用cloudkit的方法,然后在block的回调里面执行后续的操作,也就是说,都要确保在icould里面完成了修改,才能继续操作.
    
    //MARK: add new record .建立record, set value, save value, complete
    static func createRecord(_ recordData: [String: String], completion: @escaping (CKRecord?, NSError?) -> Void){
        
        let record = CKRecord(recordType: recordType)
        
        for (key, value) in recordData {
            if key == cityPicture {
                
                if let path = Bundle.main.path(forResource: value, ofType: "jpg") {
                    do{
                        let data = try Data.init(contentsOf: URL.init(fileURLWithPath: path), options: Data.ReadingOptions.mappedIfSafe)
                        record.setValue(data, forKey: key)
                    }catch let error {
                        print(error)
                    }
                }
            }else {
                record.setValue(value, forKey: key)
            }
        }
        
        publicCloudDatabase.save(record, completionHandler: { (savedRecord, error) in
            DispatchQueue.main.async {
                completion(record, error as? NSError)
            }
        })
    }
    
    
    
    //MARK: update value by recordID
    static func updateRecord(_ recordId: String, text: String, completion: @escaping (CKRecord?, NSError?) -> Void ){
        
        let recordID = CKRecordID.init(recordName: recordId)
        publicCloudDatabase.fetch(withRecordID: recordID, completionHandler: {
            (updatedRecord, error) in
            guard let record = updatedRecord else {
                DispatchQueue.main.async {
                    completion(nil, error as? NSError)
                }
                return
            }
            record.setValue(text, forKey: cityText)
            self.publicCloudDatabase.save(record, completionHandler: {
                (savedReocrd, error ) in
                DispatchQueue.main.async {
                    completion(savedReocrd, error as? NSError)
                }
            })
        })
    }
    
    
    // MARK: remove the record
    static func removeRecord(_ recordId: String, completion: @escaping (String?, NSError?) -> Void){
        
        let recordId = CKRecordID.init(recordName: recordId)
        publicCloudDatabase.delete(withRecordID: recordId, completionHandler:
            { (deletedRecordId, error) in
                DispatchQueue.main.async {
                    completion(deletedRecordId?.recordName, error as NSError?)
                }
        })
    }
    
    
    //MARK: check that user is logged
    
    static func checkLoginStatus(_ handler: @escaping (Bool) -> Void) {
        
        CKContainer.default().accountStatus { (accountStatus, error) in
            if let error = error {
                print(error.localizedDescription)
            }
            switch accountStatus {
            case .available:
                handler(true)
            default:
                handler(false)
            }
        }
    }
    
}

/* Apple 根据谓词进行查找的code
 
 
 CKDatabase *publicDatabase = [[CKContainer defaultContainer] publicCloudDatabase];
 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title = %@", @"Santa Cruz Mountains"];
 CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Artwork" predicate:predicate];
 [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
 if (error) {
 // Error handling for failed fetch from public database
 }
 else {
 // Display the fetched records
 }
 }];
 
 */


/* Apple 根据identifier 进行查找的code
 CKDatabase *publicDatabase = [[CKContainer defaultContainer] publicCloudDatabase];
 CKRecordID *artworkRecordID = [[CKRecordID alloc] initWithRecordName:@"115"];
 [publicDatabase fetchRecordWithID:artworkRecordID completionHandler:^(CKRecord *artworkRecord, NSError *error) {
 if (error) {
 // Error handling for failed fetch from public database
 }
 else {
 // Display the fetched record
 }
 }];
 */


/* Apple 查找修改的code
 // Fetch the record from the database
 CKDatabase *publicDatabase = [[CKContainer defaultContainer] publicCloudDatabase];
 CKRecordID *artworkRecordID = [[CKRecordID alloc] initWithRecordName:@"115"];
 [publicDatabase fetchRecordWithID:artworkRecordID completionHandler:^(CKRecord *artworkRecord, NSError *error) {
 if (error) {
 // Error handling for failed fetch from public database
 }
 else {
 // Modify the record and save it to the database
 NSDate *date = artworkRecord[@"date"];
 artworkRecord[@"date"] = [date dateByAddingTimeInterval:30.0 * 60.0];
 [publicDatabase saveRecord:artworkRecord completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
 // Error handling for failed save to public database
 }];
 }
 }];

*/


/*  Apple 创建保存record
 CKRecordID *artworkRecordID = [[CKRecordID alloc] initWithRecordName:@"115"];
 CKRecord *artworkRecord = [[CKRecord alloc] initWithRecordType:@"Artwork" recordID:artworkRecordID];
 artworkRecord[@"title" ] = @"MacKerricher State Park";
 artworkRecord[@"artist"] = @"Mei Chen";
 artworkRecord[@"address"] = @"Fort Bragg, CA";
 
 To get the public database:
 CKContainer *myContainer = [CKContainer defaultContainer];
 CKDatabase *publicDatabase = [myContainer publicCloudDatabase];
 
 To get the private database:
 CKContainer *myContainer = [CKContainer defaultContainer];
 CKDatabase *privateDatabase = [myContainer privateCloudDatabase];
 
 To get a custom container:
 CKContainer *myContainer = [CKContainer containerWithIdentifier:@"iCloud.com.example.ajohnson.GalleryShared"];

 [publicDatabase saveRecord:artworkRecord completionHandler:^(CKRecord *artworkRecord, NSError *error){
 if (!error) {
 // Insert successfully saved record code
 }
 else {
 // Insert error handling
 }
 }];
 
 */


/* Apple alert权限
 
 [[CKContainer defaultContainer] accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
 if (accountStatus == CKAccountStatusNoAccount) {
 UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign in to iCloud"
 message:@"Sign in to your iCloud account to write records. On the Home screen, launch Settings, tap iCloud, and enter your Apple ID. Turn iCloud Drive on. If you don't have an iCloud account, tap Create a new Apple ID."
 preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"Okay"
 style:UIAlertActionStyleCancel
 handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
 }
 else {
 // Insert your just-in-time schema code here
 }
 }];
 */




