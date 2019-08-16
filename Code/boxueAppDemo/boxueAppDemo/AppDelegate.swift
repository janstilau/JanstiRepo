//
//  AppDelegate.swift
//  boxueAppDemo
//
//  Created by JustinLau on 2019/8/9.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    /**
    这个函数, 会在 window 生成之后调用. 如果 info plist 文件里面, 设置了 window 的 storyBoard, 那么 application 就会加载这个 xib , 然后设置为 app 的 window. 这个流程, 是为了方便程序通过 stroyboard 进行 VC 的创建, 不过在国内环境下, 基本上是代码控制界面的跳转.
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nil
        window?.makeKeyAndVisible()
        
        return true
    }



}

