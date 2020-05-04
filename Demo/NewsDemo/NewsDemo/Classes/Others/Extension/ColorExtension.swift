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
}
