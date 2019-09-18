//
//  MoodSource.swift
//  Moody
//
//  Created by Florian on 27/08/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import CoreData

/**
 如果是 OC 里面, 这会是一个数据类, 里面一个 enum 值, 然后一个Country, 一个 Continent, 根据 type 值来取不同的数据.
 首先这样就有数据的冗余了, 一个类里面的数据, 必然在某个时候只会用到一个, 让使用者很不舒服.
 Enum 的关联对象的技术, 很好的解决了这个问题, 并且, 作为一个独立的类型, 可以在里面添加相关联的函数.
 */

enum MoodSource {
    case country(Country)
    case continent(Continent)
}


extension MoodSource {
    init(region: NSManagedObject) {
        if let country = region as? Country {
            self = .country(country)
        } else if let continent = region as? Continent {
            self = .continent(continent)
        } else {
            fatalError("\(region) is not a valid mood source")
        }
    }

    var predicate: NSPredicate {
        switch self  {
        case .country(let c):
            return NSPredicate(format: "country = %@", argumentArray: [c])
        case .continent(let c):
            return NSPredicate(format: "country in %@", argumentArray: [c.countries])
        }
    }

    var managedObject: NSManagedObject? {
        switch self {
        case .country(let c): return c
        case .continent(let c): return c
        }
    }
}


extension MoodSource: LocalizedStringConvertible {
    var localizedDescription: String {
        switch self  {
        case .country(let c): return c.localizedDescription
        case .continent(let c): return c.localizedDescription
        }
    }
}

