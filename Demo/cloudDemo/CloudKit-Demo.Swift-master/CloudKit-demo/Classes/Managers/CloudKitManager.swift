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
 
 During development, it’s easy to create a schema using CloudKit APIs. When you save record objects to a database, the associated record types and their fields are automatically created for you. This feature is called just-in-time schema and is available only when you use the development environment which is not accessible by apps sold on the store. For example, during development you can populate a CloudKit database with test records stored in a property list.
 

*/

// 上面的什么意思呢,就是在api里面,save这个操作,会让dashBoard里面,生成相应的类型和数据
// 比如,生成一个person的对象,设置name,age,face等类型,然后save,就会自动生成person这样的一个类型,然后name为string,age为int,face为asset或者是bytes.



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
            
            let personId = CKRecordID.init(recordName: "James")
            publicCloudDatabase.fetch(withRecordID: personId, completionHandler: { (fetchRecord, error) in
                if error != nil {
                    
                    let person = CKRecord.init(recordType: "Artist", recordID: personId)
                    person.setValue("LBJ", forKey: "name")
                    publicCloudDatabase.save(person, completionHandler: { (saveRecord, error) in
                        let personRef = CKReference.init(record: person, action: CKReferenceAction.none)
                        record.setValue(personRef, forKey: "artist")
                        self.publicCloudDatabase.save(record) { savedRecord, error in
                            DispatchQueue.main.async {
                                completion(savedRecord, error as? NSError)
                            }
                        }
                    })
                    
                }else {
                    
                }
            })
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






/* 根据recordId ,获取refrence关联的record
 Get the reference field.
 CKRecord *artworkRecord;
 …
 CKReference *referenceToArtist = artworkRecord[@"artist"];
 Get the target record ID from the reference.
 CKRecordID *artistRecordID = artistReference.recordID;
 Fetch the target record.
 [publicDatabase fetchRecordWithID:artistRecordID completionHandler:^(CKRecord *artistRecord, NSError *error) {
 if (error) {
 // Failed to fetch record
 }
 else {
 // Successfully fetched record
 }
 }];
 */

/* 批量获取ref
 
 Start with the parent record ID (CKRecordID) that you previously fetched and the model object for the parent.
 For example, create an Artist model object from an Artist record.
 
 __block Artist *artist = [[Artist alloc] initWithRecord:artistRecord];
 Use __block so that you can access the parent object in the completion handler later.
 Create a predicate object to fetch the child records.
 NSPredicate *predicate = [NSPredicate predicateWithFormat:@“artist = %@”, artistRecordID];
 In your code, replace artist with the name of the reference field in the child record, and replace artistRecordID with the parent record ID.
 Note: Possible values for the right-hand expression in the predicate format string parameter include CKRecord, CKRecordID, and CKReference objects.
 Create a query object specifying the record type to search.
 CKQuery *query = [[CKQuery alloc] initWithRecordType:@“Artwork” predicate:predicate];
 In your code, replace @“Artwork” with the name of the child record type.
 Perform the fetch.
 CKDatabase *publicDatabase = [[CKContainer defaultContainer] publicCloudDatabase];
 [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
 if (error) {
 // Failed to fetch children of parent
 }
 else {
 // Create model objects for each child and set the one-to-many relationship from the parent to its children
 }
 }];
 Add the code to the else statement that creates the corresponding relationships between your model objects.

 
 */

























