//
//  ManageContextContainer.swift
//  Moody
//
//  Created by JustinLau on 2019/12/4.
//  Copyright © 2019 objc.io. All rights reserved.
//

import Foundation
import CoreData

protocol ManageContextContainer: AnyObject {
    var managedObjectContext: NSManagedObjectContext! { get set }
}
