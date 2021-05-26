#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

/*
    ConstraintDSL 被下面的三个 DSL 实现. 三个 DSL 仅仅是封装了不同的 Item.
    View, layoutGuide, LayoutSupport
 */

// ConstraintDSL 的抽象是, 里面存储了一个 target, 作为 autolyout 的对象.

public protocol ConstraintDSL {
    
    var target: AnyObject? { get }
    
    func setLabel(_ value: String?)
    func label() -> String?
    
}


extension ConstraintDSL {
    
    public func setLabel(_ value: String?) {
        objc_setAssociatedObject(self.target as Any, &labelKey, value, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }
    public func label() -> String? {
        return objc_getAssociatedObject(self.target as Any, &labelKey) as? String
    }
    
}

private var labelKey: UInt8 = 0


public protocol ConstraintBasicAttributesDSL : ConstraintDSL {
    
}

// 这些, protocol 的定义, 主要是想要给实现类, 定义一些公用的方法.
// 对于一个 DSL 来说, 它的公共的方法, 就是返回自己 target 的对应 attributeItem

extension ConstraintBasicAttributesDSL {
    
    // MARK: Basics
    
    public var left: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.left)
    }
    
    public var top: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.top)
    }
    
    public var right: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.right)
    }
    
    public var bottom: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.bottom)
    }
    
    public var leading: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.leading)
    }
    
    public var trailing: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.trailing)
    }
    
    public var width: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.width)
    }
    
    public var height: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.height)
    }
    
    public var centerX: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.centerX)
    }
    
    public var centerY: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.centerY)
    }
    
    public var edges: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.edges)
    }
    
    public var directionalEdges: ConstraintItem {
      return ConstraintItem(target: self.target, attributes: ConstraintAttributes.directionalEdges)
    }

    public var horizontalEdges: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.horizontalEdges)
    }

    public var verticalEdges: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.verticalEdges)
    }

    public var directionalHorizontalEdges: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.directionalHorizontalEdges)
    }

    public var directionalVerticalEdges: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.directionalVerticalEdges)
    }

    public var size: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.size)
    }
    
    public var center: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.center)
    }
    
}

public protocol ConstraintAttributesDSL : ConstraintBasicAttributesDSL {
}

extension ConstraintAttributesDSL {
    
    // MARK: Baselines
    @available(*, deprecated, renamed:"lastBaseline")
    public var baseline: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.lastBaseline)
    }
    
    @available(iOS 8.0, OSX 10.11, *)
    public var lastBaseline: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.lastBaseline)
    }
    
    @available(iOS 8.0, OSX 10.11, *)
    public var firstBaseline: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.firstBaseline)
    }
    
    // MARK: Margins
    
    @available(iOS 8.0, *)
    public var leftMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.leftMargin)
    }
    
    @available(iOS 8.0, *)
    public var topMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.topMargin)
    }
    
    @available(iOS 8.0, *)
    public var rightMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.rightMargin)
    }
    
    @available(iOS 8.0, *)
    public var bottomMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.bottomMargin)
    }
    
    @available(iOS 8.0, *)
    public var leadingMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.leadingMargin)
    }
    
    @available(iOS 8.0, *)
    public var trailingMargin: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.trailingMargin)
    }
    
    @available(iOS 8.0, *)
    public var centerXWithinMargins: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.centerXWithinMargins)
    }
    
    @available(iOS 8.0, *)
    public var centerYWithinMargins: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.centerYWithinMargins)
    }
    
    @available(iOS 8.0, *)
    public var margins: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.margins)
    }
    
    @available(iOS 8.0, *)
    public var directionalMargins: ConstraintItem {
      return ConstraintItem(target: self.target, attributes: ConstraintAttributes.directionalMargins)
    }

    @available(iOS 8.0, *)
    public var centerWithinMargins: ConstraintItem {
        return ConstraintItem(target: self.target, attributes: ConstraintAttributes.centerWithinMargins)
    }
    
}
