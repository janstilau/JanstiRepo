//
//  City.swift
//  reInputCloudDemo
//
//  Created by jansti on 16/11/24.
//  Copyright © 2016年 jansti. All rights reserved.
//

import UIKit
import CloudKit

let cityName = "name"
let cityText = "text"
let cityPicture = "picture"

private let kCitiesSourcePlist = "Cities"

class City: Equatable {
    
//    lazy static var cities: [[String : String]]! = {
//       
//        let path = Bundle.main.path(forResource: kCitiesSourcePlist, ofType: "plist")
//        let plistData = try? Data.init(contentsOf: URL.init(fileURLWithPath: path!))
//        assert(plistData != nil, "Source not exist")
//        
//        return cities
//    }()
    // 上面这样写,有了两个错误 1 lazy may not be used on an already-lazy global 也就是说,对于static 的类变量来说,本身swift已经让它成为了lazy 2 variable used within its own initial value, 在自己的lazy block里面赋值,然后返回自己是不可以的.
    private static var plistData: [[String : String]]!

    static var cities: [[String : String]]!{
        if plistData == nil {
            let path = Bundle.main.path(forResource: kCitiesSourcePlist, ofType: "plist")
            guard let plistPath = path else {
                assert(false, "plist not exist")
            }
            let data = try? Data.init(contentsOf: URL.init(fileURLWithPath: plistPath))
            assert(data != nil, "cannot archive data form plist")
            
            do {
                plistData = try PropertyListSerialization.propertyList(from: data!, options:.mutableContainersAndLeaves, format: nil) as! [[String: String]]
            }catch {
                print("cannot read data from the plist")
            }
        }
        
        return plistData
    }
    var name: String
    var text: String
    var image: UIImage?
    var identifier: String
    
    init(record: CKRecord){
        self.name = record.value(forKey: cityName) as! String
        self.text = record.value(forKey: cityText) as! String
        if let imageData = record.value(forKey: cityPicture) as? Data{
            self.image = UIImage.init(data: imageData)
        }
        self.identifier = record.recordID.recordName
    }
    
    static func ==(lhs: City, rhs: City) -> Bool{
        return lhs.identifier == rhs.identifier
    }
    // Self is only avaiable in a protocol or as the result of a method in a class
    
    
}
