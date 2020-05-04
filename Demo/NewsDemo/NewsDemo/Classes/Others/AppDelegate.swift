//
//  AppDelegate.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/3.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // 因为, window 是在 didFinishLaunchingWithOptions 这个方法之后才会设置的, 所以这里要用 Optinal 进行设置. 相应的, 调用的时候, 都要用可选链进行调用.
    // 可选链的使用, 使得可选类型的值在调用的时候, 和之前 OC 基本没有区别了.
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MyTabBarController()
        window?.makeKeyAndVisible()
        return true
    }
    
}

