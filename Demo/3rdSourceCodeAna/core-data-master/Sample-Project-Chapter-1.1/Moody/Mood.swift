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

    @NSManaged public var colors: NSObject?
    @NSManaged public var date: Date?
 */
// final 代表着, 这个类不应该被子类化.

final class Mood: NSManagedObject {
    @NSManaged fileprivate(set) var date: Date
    @NSManaged fileprivate(set) var colors: [UIColor]
    // fileprivate(set), 控制着该类的 date, colors 应该是一个不可变的数据.
    
    // 添加数据到上下文的责任, 被转移到了 Mood 类中. 而保存上下文的责任, 则在上下文的责任中.
    static func insert(into context: NSManagedObjectContext, image: UIImage) -> Mood {
        let mood: Mood = context.insertObject()
        mood.colors = image.moodColors
        mood.date = Date()
        return mood
    }
}

// Mood 复写了 ManagedObject 的默认实现, 特化了 defaultSortDescriptors 的功能
extension Mood: ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        // NSSortDescriptor 的构造函数, 就是接受一个 String 就可以了. #keyPath 带来了保护作用, 如果传入的值非法, 会直接报错的. 具体原理没有深入.
        return [NSSortDescriptor(key: #keyPath(date), ascending: false)]
    }
}


fileprivate let MaxColors = 8

extension UIImage {
    fileprivate var moodColors: [UIColor] {
        var colors: [UIColor] = []
        for c in dominantColors(.Moody) where colors.count < MaxColors {
            colors.append(c)
        }
        return colors
    }
}

