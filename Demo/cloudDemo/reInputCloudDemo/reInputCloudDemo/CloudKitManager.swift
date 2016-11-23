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

class City {
    
    
    init(record: CKRecord){
        
    }
}

final class CloudKitManager {
    
    fileprivate init(){
        
    }//  这里什么意思呢,let manager = CluodKitManager(), 这句话如果在别的文件里面进行书写会报错, isnot inaccessible, cause fileprivate,所以在这里添加了访问权限的设置,这样就是让在外界不能通过生成实例来访问这个方法了.
    
    static var publicCloudDatabase: CKDatabase{
        return CKContainer.default().publicCloudDatabase
    }
    
    
    // MARK: Retrieve existing records
    static func fetchAllCities(_ completion:@escaping (_ records: [City]?,_ error: NSError?) -> Void){
        let predicate = NSPredicate.init(value: true)
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
    
    func method(hander: (Int, Double) -> ()) {
        
        
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




