//
//  ColorExtension.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat = 0.0) {
        self.init(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: alpha)
    }
    
    static func randomColor() -> UIColor {
        return UIColor(red: CGFloat.random(in: 0.0...255.0) / 255.0,
                       green: CGFloat.random(in: 0.0...255.0) / 255.0,
                       blue: CGFloat.random(in: 0.0...255.0) / 255.0,
                       alpha: 1)
    }
    
    static func globalBGColor() -> UIColor {
        return UIColor(r: 248, g: 249, b: 247)
    }
    
    static func globalBackgroundColor() -> UIColor {
        return UIColor(r: 248, g: 249, b: 247)
    }

    /// 背景红色
    static func globalRedColor() -> UIColor {
        return UIColor(r: 230, g: 100, b: 95)
    }

    /// 背景灰色 132
    static func grayColor132() -> UIColor {
        return UIColor(r: 132, g: 132, b: 132)
    }

    /// 背景灰色 232
    static func grayColor232() -> UIColor {
        return UIColor(r: 232, g: 232, b: 232)
    }
}



