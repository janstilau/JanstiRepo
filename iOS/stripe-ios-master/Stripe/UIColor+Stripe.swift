//
//  UIColor+Stripe.swift
//  StripeiOS
//
//  Created by Yuki Tokuhiro on 11/16/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            
            // Creates a color object that uses the specified block to generate its color data dynamically.
            /*
             UITraitCollection
             
             The iOS interface environment for your app, including traits such as horizontal and vertical size class, display scale, and user interface idiom
             
             UITraitCollection 就是一个数据盒子. 从中不断的读取, 当前的 iOS 设备的界面信息.
             
             */
            return UIColor.init {
                switch $0.userInterfaceStyle {
                case .light, .unspecified:
                    return light
                case .dark:
                    return dark
                @unknown default:
                    return light
                }
            }
        }
        return light
    }
}
