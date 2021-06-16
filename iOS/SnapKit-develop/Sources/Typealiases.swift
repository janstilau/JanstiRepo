import Foundation


/*
    一般第三方类库, 要使用这个技法.
    各种 Typealias 将不同平台下的相似类, 进行了封装.
    在类库内部, 使用重命名后的类型进行编程.
 */


#if os(iOS) || os(tvOS)
    import UIKit
#if swift(>=4.2)
    typealias LayoutRelation = NSLayoutConstraint.Relation
    typealias LayoutAttribute = NSLayoutConstraint.Attribute
#else
    typealias LayoutRelation = NSLayoutRelation
    typealias LayoutAttribute = NSLayoutAttribute
#endif
    typealias LayoutPriority = UILayoutPriority
#else
    import AppKit
    typealias LayoutRelation = NSLayoutConstraint.Relation
    typealias LayoutAttribute = NSLayoutConstraint.Attribute
    typealias LayoutPriority = NSLayoutConstraint.Priority
#endif

