//
//  AppDelegate.swift
//  Moody
//
//  Created by Florian on 07/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import CoreData


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    /**
     persistentContainer 这个值, 会在程序一开始启动的时候设置值, 所以之后使用的时候一定会有值, 这里用的隐式解包的符号进行了标志.
     如果这里不设置为 optional, 那么就需要在 init 方法里面进行初始化操作.
     包括在RootViewController中,  context 也是隐式解包的. 也是为了不进行初始化操作, 因为这个值是需要外接才能获得的.
     */
    var persistentContainer: NSPersistentContainer!
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        /**
         在建立了 coreData Stack 之后, 将这个 Container 进行了保存, 然后将 context 传递给了 vc 上
         */
        createMoodyContainer { container in
            self.persistentContainer = container
            let storyboard = self.window?.rootViewController?.storyboard
            guard let vc = storyboard?.instantiateViewController(withIdentifier: "RootViewController") as? RootViewController
                else { fatalError("Cannot instantiate root view controller") }
            vc.managedObjectContext = container.viewContext
            self.window?.rootViewController = vc
        }
        return true
    }
}

