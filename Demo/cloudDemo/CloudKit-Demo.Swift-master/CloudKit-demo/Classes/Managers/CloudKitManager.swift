//
//  YALCloudKitManager.swift
//  CloudKit-demo
//
//  Created by Maksim Usenko on 3/25/15.
//  Copyright (c) 2015 Yalantis. All rights reserved.
//

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
    
    fileprivate init() {
        ///forbide to create instance of helper class
    }//  这里什么意思呢,let manager = CluodKitManager(), 这句话如果在别的文件里面进行书写会报错, isnot inaccessible, cause fileprivate,所以在这里添加了访问权限的设置,这样就是让在外界不能通过生成实例来访问这个方法了.
    
    static var publicCloudDatabase: CKDatabase {
        return CKContainer.default().publicCloudDatabase
    }
    
    //MARK: Retrieve existing records
    static func fetchAllCities(_ completion: @escaping (_ records: [City]?, _ error: NSError?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            let cities = records?.map(City.init(record:))
            DispatchQueue.main.async {
                completion(cities, error as NSError?)
            }
        }
    }
    
    //MARK: add a new record
    static func createRecord(_ recordData: [String: String], completion: @escaping (_ record: CKRecord?, _ error: NSError?) -> Void) {
        let record = CKRecord(recordType: recordType)
        
        for (key, value) in recordData {
            if key == cityPicture {
                if let path = Bundle.main.path(forResource: value, ofType: "jpg") {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                        record.setValue(data, forKey: key)
                    } catch let error {
                        print(error)
                    }
                }
            } else {
                record.setValue(value, forKey: key)
            }
        }
        
        publicCloudDatabase.save(record) { (savedRecord, error) in
            DispatchQueue.main.async {
                completion(record, error as? NSError)
            }
        }
    }
    
    //MARK: updating the record by recordId
    static func updateRecord(_ recordId: String, text: String, completion: @escaping (CKRecord?, NSError?) -> Void) {
        let recordId = CKRecordID(recordName: recordId)
        publicCloudDatabase.fetch(withRecordID: recordId) { updatedRecord, error in
            guard let record = updatedRecord else {
                DispatchQueue.main.async {
                    completion(nil, error as NSError?)
                }
                return
            }
            
            record.setValue(text, forKey: cityText)
            self.publicCloudDatabase.save(record) { savedRecord, error in
                DispatchQueue.main.async {
                    completion(savedRecord, error as? NSError)
                }
            }
        }
    }
    
    //MARK: remove the record
    static func removeRecord(_ recordId: String, completion: @escaping (String?, NSError?) -> Void) {
        let recordId = CKRecordID(recordName: recordId)
        publicCloudDatabase.delete(withRecordID: recordId, completionHandler: { deletedRecordId, error in
            DispatchQueue.main.async {
                completion (deletedRecordId?.recordName, error as NSError?)
            }
        })
    }
    
    //MARK: check that user is logged
    static func checkLoginStatus(_ handler: @escaping (_ islogged: Bool) -> Void) {
        CKContainer.default().accountStatus{ accountStatus, error in
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

