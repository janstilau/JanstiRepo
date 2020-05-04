//
//  MyTabBar.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

class MyTabBar: UITabBar {

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(publishBtn)
    }
    
    /*
     private 绝对私有, 除了在当前类中可以访问, 其他任何类或者当前了类的扩展中, 不能够访问
     fileprivate 文件私有, 可以在当前类文件中访问, 其他文件不能访问
     open 可以在任何类文件中访问
     internal 默认
     这里, 懒加载的方式, 要比之前 OC 的要舒服的多.
     之前 OC 的懒加载, 还专门需要占用一段空间去定义, 这里直接是在属性的定义的时候就写好了.
     很多属性, 其实是对象生成的时候, 就跟着生成, 所以, 懒加载其实没有多大作用, 在生成的时候, 直接创建出来就可以了, 用懒加载, 反而是代码逻辑不清.
     这里, 生成代码和属性放在一起, 逻辑更加紧密, 可以将生成代码直接放在这里, 而不放到了 setup 代码里面
     */
    private lazy var publishBtn: UIButton = {
        let publishBtn = UIButton(type: .custom)
        // 这里, setBackgroundImage 的第一个参数, 是 UIImage?, 就避免了先检查 UIImage 是否生成, 再去赋值的繁琐的尴尬.
        // API 的设计, 还是尽量的兼容了 OC.
        publishBtn.setBackgroundImage(UIImage(named: "feed_publish_44x44_"), for: .normal)
        publishBtn.setBackgroundImage(UIImage(named: "feed_publish_press_44x44_"), for: .selected)
        publishBtn.sizeToFit()
        return publishBtn
    }()
    
    
    // 这里, 必须要实现 required init?(coder: NSCoder) 方法, 因为, 父类是实现了 NSCoding 的协议.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        // 这里, CGFloat 是一个 Struct, 而不是 Double 的别名. 不清楚为什么这样设计出来.
        let width = bounds.width
        let height = bounds.height
        let btnWidth = width / 5.0
        let btnHeight = height

        publishBtn.center = CGPoint(x: width*0.5, y: height*0.5-7)

        // 这里, 不太明白为什么可以这样.
        var index = 0
        for tabBtn in subviews {
            if !tabBtn.isKind(of: NSClassFromString("UITabBarButton")!) { continue }
            let btnIdx = index>1 ? index+1: index
            tabBtn.frame = CGRect(x: btnWidth*CGFloat(btnIdx), y: 0, width: btnWidth, height: btnHeight)
            index+=1
        }
    }
}
