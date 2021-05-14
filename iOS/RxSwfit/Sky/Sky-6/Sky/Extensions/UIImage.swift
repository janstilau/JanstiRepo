//
//  UIImage.swift
//  Sky
//
//  Created by Mars on 12/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

// 直接在 UIImage 里面添加方法.
extension UIImage {
    
    // 将方法, 设置为 UIImage 的方法, 这样外界可以使用 .weatherIcon 的方式调用
    class func weatherIcon(of name: String) -> UIImage? {
        switch name {
        case "clear-day":
            return UIImage(named: "clear-day")
        case "clear-night":
            return UIImage(named: "clear-night")
        case "rain":
            return UIImage(named: "rain")
        case "snow":
            return UIImage(named: "snow")
        case "sleet":
            return UIImage(named: "sleet")
        case "wind":
            return UIImage(named: "wind")
        case "cloudy":
            return UIImage(named: "cloudy")
        case "partly-cloudy-day":
            return UIImage(named: "partly-cloudy-day")
        case "partly-cloudy-night":
            return UIImage(named: "partly-cloudy-night")
        default:
            return UIImage(named: "clear-day")
        }
    }
    
}
