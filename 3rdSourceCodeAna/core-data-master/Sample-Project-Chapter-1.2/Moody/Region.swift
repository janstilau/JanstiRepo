//
//  Region.swift
//  Moody
//
//  Created by Florian on 03/09/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData

/*
 @nonobjc public class func fetchRequest() -> NSFetchRequest<Region> {
     return NSFetchRequest<Region>(entityName: "Region")
 }

 @NSManaged public var numericISO3166Code: NSNumber?
 @NSManaged public var updatedAt: Date?
 
 */

/*
 在 Region 的代码里面, 没有 numericISO3166Code, 和 updatedAt 这两个值, 因为实际上没有 Region 这个类的使用, 直接使用的是 Continent 和 Conutry 类.
 */

final class Region: NSManagedObject {}

extension Region: ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: "updatedAt", ascending: false)]
    }
}

