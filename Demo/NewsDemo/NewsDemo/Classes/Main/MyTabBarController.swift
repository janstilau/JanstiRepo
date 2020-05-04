//
//  MyTabBarController.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/3.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

class MyTabBarController: UITabBarController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 这里, 父类的属性, 也可以直接不用 self 就取用到了.
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewControllers()
        congireViews()
    }
    
    /*
     调用方法的时候, 不写 self, 是对的.
     因为, 应该尽量避免全局函数的定义. 因为, 函数定义其实作用域在全局, 而面向对象, 就是让函数在类的范围内.
     而如果是在类的范围内, 就应该调用的就是类的方法. 所以, 写 self 没有太大的意义.
     当然, 会有一些方法, 是全局的方法. 不过这些方法, 都应该是标准库的方法.
     
     而变量, 直接使用不加 self 修饰, 感觉有点问题, 因为变量可能会导致成员变量的不明显. 感觉还是需要, 用特殊的值进行成员变量的标识.
     */
    func setupViewControllers() {
        setupChildController(HomeViewController(),
                             title: "首页",
                             imageName: "home_tabbar_32x32_",
                             selectedImageName: "home_tabbar_press_32x32_")
        setupChildController(VideoViewController(),
                             title: "视频",
                             imageName: "video_tabbar_32x32_",
                             selectedImageName: "video_tabbar_press_32x32_")
        setupChildController(HuoshanViewController(),
                             title: "小视频",
                             imageName: "huoshan_tabbar_32x32_",
                             selectedImageName: "huoshan_tabbar_press_32x32_")
        setupChildController(MineViewController(),
                             title: "我的",
                             imageName: "mine_tabbar_32x32_",
                             selectedImageName: "mine_tabbar_press_32x32_")
    }
    
    func setupChildController(_ childVC: UIViewController,
                              title: String,
                              imageName: String,
                              selectedImageName: String) {
        childVC.tabBarItem.title = title
        childVC.tabBarItem.image = UIImage(named: imageName)
        childVC.tabBarItem.selectedImage = UIImage(named: selectedImageName)
        childVC.title = title
        
        let navVC = MyNavigationController(rootViewController: childVC)
        addChild(navVC)
    }
    
    func congireViews()  {
        let tabbar = UITabBar.appearance()
        tabbar.tintColor = UIColor(red: 245/255.0, green: 90/255.0, blue: 93/255.0, alpha: 1.0)
        // tabBar 是 Readonly 的, 可以用 KVC 进行设置.
        // KVC 是 NSObject 里面的方法, 而 UIViewController 是继承自 NSObject 的.
        // 对于标准类库提供的大部分的类, 还是继承自 NSObejct 的. 所以, Apple 还是使用了 NSObejct 的大部分的方法, 因为很多机制是根据 NSObejct 实现的.
        // 而对于很多的我们自己的业务类, 可以使用纯的 Swfit 结构体, 来进行业务的分化.
        setValue(MyTabBar(), forKey: "tabBar")
    }

}
