//
//  SegueHandler.swift
//  Moody
//
//  Created by Florian on 12/06/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import UIKit

// 协议, 更多的像是一个抽象类, 在这个抽象类中, 提取了部分代码过来, 增加了复用的可能.
protocol SeguePerformer {
     associatedtype SegueIdentifier: RawRepresentable
}

// 实现类必须是一个 VC, 实现类指定的 SegueIdentifier 的 rawValue 必须是字符串.
extension SeguePerformer where Self: UIViewController, SegueIdentifier.RawValue == String {
    // 这个函数, 通过字符串的值获取到 枚举值, 枚举创建的工作, 被调到了协议的内部了.
    func segueIdentifier(for segue: UIStoryboardSegue) -> SegueIdentifier {
        guard let identifier = segue.identifier,
            let segueIdentifier = SegueIdentifier(rawValue: identifier)
        else { fatalError("Unknown segue: \(segue))") }
        return segueIdentifier
    }
    // 这个函数, 将 performSegue 从 enum 值转化成为了 字符串值, 因为 where 后面的限制, 所以这些函数可以放心的使用.
    func performSegue(withIdentifier segueIdentifier: SegueIdentifier) {
        performSegue(withIdentifier: segueIdentifier.rawValue, sender: nil)
    }
}


