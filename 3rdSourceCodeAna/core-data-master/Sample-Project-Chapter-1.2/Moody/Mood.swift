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
 @nonobjc public class func fetchRequest() -> NSFetchRequest<Mood> {
     return NSFetchRequest<Mood>(entityName: "Mood")
 }

 @NSManaged public var audio: Data?
 @NSManaged public var colors: NSObject?
 @NSManaged public var date: Date?
 @NSManaged public var latitude: NSNumber?
 @NSManaged public var likeNum: Int64
 @NSManaged public var longitude: NSNumber?
 @NSManaged public var country: Country?
 */


final class Mood: NSManagedObject {
    @NSManaged fileprivate(set) var date: Date
    @NSManaged fileprivate(set) var colors: [UIColor]
    @NSManaged public fileprivate(set) var country: Country

    public var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat.doubleValue, longitude: lon.doubleValue)
    }

    public static func insert(into context: NSManagedObjectContext, image: UIImage, location: CLLocation?, placemark: CLPlacemark?) -> Mood {
        let mood: Mood = context.insertObject()
        mood.colors = image.moodColors
        mood.date = Date()
        if let coord = location?.coordinate { // optianl chain.
            mood.latitude = NSNumber(value: coord.latitude)
            mood.longitude = NSNumber(value: coord.longitude)
        }
        let isoCode = placemark?.isoCountryCode ?? ""
        let isoCountry = ISO3166.Country.fromISO3166(isoCode) // default return unknown. country 必有值.
        // 每一个 entity 的创建工作, 都是由自己的类型进行负责.
        mood.country = Country.findOrCreate(for: isoCountry, in: context)
        return mood
    }

    override public func prepareForDeletion() {
        if country.moods.filter({ !$0.isDeleted }).isEmpty {
            managedObjectContext?.delete(country)
        }
    }


    // MARK: Private
    // private 的属性, 写到最后, 这是 Swift 的习惯吗??
    @NSManaged fileprivate var latitude: NSNumber?
    @NSManaged fileprivate var longitude: NSNumber?
}


extension Mood: ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: #keyPath(date), ascending: false)]
    }
}


private let MaxColors = 8

extension UIImage {
    fileprivate var moodColors: [UIColor] {
        var colors: [UIColor] = []
        for c in dominantColors(.Moody) where colors.count < MaxColors {
            colors.append(c)
        }
        return colors
    }
}

