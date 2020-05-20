//
//  Model.swift
//  Moody
//
//  Created by Florian on 07/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

/*
 @objc(addMoodsObject:)
 @NSManaged public func addToMoods(_ value: Mood)

 @objc(removeMoodsObject:)
 @NSManaged public func removeFromMoods(_ value: Mood)

 @objc(addMoods:)
 @NSManaged public func addToMoods(_ values: NSSet)

 @objc(removeMoods:)
 @NSManaged public func removeFromMoods(_ values: NSSet)
 */

final class Country: NSManagedObject {
    @NSManaged fileprivate(set) var moods: Set<Mood> // 关系
    @NSManaged fileprivate(set) var continent: Continent? // 关系. 这一个并不是必须的.
    
    @NSManaged var updatedAt: Date
    /**
     numericISO3166Code 必须以 int 的形式进行存储, 而我们需要的, 是一个枚举值.
     */
    fileprivate(set) var iso3166Code: ISO3166.Country {
        // 根据内部存储的值, 构造一个合适的 enum 值进行返回.
        get {
            guard let country = ISO3166.Country(rawValue: numericISO3166Code) else { fatalError("Unknown country code") }
            return country
        }
        // 修改内部的存储值.
        set {
            numericISO3166Code = newValue.rawValue
        }
    }

    static func findOrCreate(for isoCountry: ISO3166.Country, in context: NSManagedObjectContext) -> Country {
        let predicate = NSPredicate(format: "%K == %d", #keyPath(numericISO3166Code), Int(isoCountry.rawValue))
        let country = findOrCreate(in: context, matching: predicate) {
            $0.iso3166Code = isoCountry
            $0.updatedAt = Date()
            $0.continent = Continent.findOrCreateContinent(for: isoCountry, in: context)
        }
        return country
    }

    // 一个切口, 用来执行某些自定义的操作.
    override func prepareForDeletion() {
        guard let continent = continent else { return }
        if continent.countries.filter({ !$0.isDeleted }).isEmpty {
            managedObjectContext?.delete(continent)
        }
    }


    // MARK: Private
    // 在真正的存储 numericISO3166Code 的时候, 还是使用的是 Int16 这个类型, 但是外界的表现, 使用了 set, get 方法, 进行了包装, 并且, 该属性的命名为 numericISO3166Code, 是一个底层存储的属性. 暴露在外的, 则是一个计算属性.
    @NSManaged fileprivate var numericISO3166Code: Int16
}


extension Country: ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: #keyPath(updatedAt), ascending: false)]
    }
}

