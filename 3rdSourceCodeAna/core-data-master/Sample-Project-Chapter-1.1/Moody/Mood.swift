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


final class Mood: NSManagedObject {
    @NSManaged fileprivate(set) var date: Date
    @NSManaged fileprivate(set) var colors: [UIColor]

    // 这个方法, 作为修改数据库的唯一的一个入口, 使得 date, colors 的修改, 仅仅限制在这个文件的内部.
    // 添加数据到上下文的责任, 被转移到了 Mood 类中. 而保存上下文的责任, 则在上下文的责任中.
    static func insert(into context: NSManagedObjectContext, image: UIImage) -> Mood {
        /**
         这里, 通过返回值确定了 insertObject 中的类型,
         context.insertObject<Mood>()
         Cannot specialize a non-generic definition
         上面的写法, 会报这样的错误, 也就是说, 泛型函数只能通过参数类型来进行确定, 在 swift 中, 还可以通过返回值的类型进行确认.
         */
        let mood: Mood = context.insertObject()
        mood.colors = image.moodColors
        mood.date = Date()
        return mood
    }
}

/**
 在 protocol 中, extension 中增加了 defaultSortDescriptors 的一个默认实现, 是返回一个空数组, 而在 Mood 中, 显式的定义了这个实现的方式, 就是通过 date 进行排序操作.
 */
extension Mood: ManagedObject {
    static var defaultSortDescriptors: [NSSortDescriptor] {
        // NSSortDescriptor 是一个带有极强的 oc 风格的类, 运用了运行时的机制.
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

