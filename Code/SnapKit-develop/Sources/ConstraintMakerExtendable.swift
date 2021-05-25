#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

// 所谓的链式编程, 只不过是各种属性, 仅仅是添加一份数据, 然后返回自身罢了
// 而 第一个 left, 而是 maker 来创建除了一个 ConstraintMakerExtendable 对象出来.

public class ConstraintMakerExtendable: ConstraintMakerRelatable {
    
    
    // 各种操作, 不过是向自己引用的盒子里面添加数据而已.
    public var left: ConstraintMakerExtendable {
        self.description.attributes += .left
        return self
    }
    
    public var top: ConstraintMakerExtendable {
        self.description.attributes += .top
        return self
    }
    
    public var bottom: ConstraintMakerExtendable {
        self.description.attributes += .bottom
        return self
    }
    
    public var right: ConstraintMakerExtendable {
        self.description.attributes += .right
        return self
    }
    
    public var leading: ConstraintMakerExtendable {
        self.description.attributes += .leading
        return self
    }
    
    public var trailing: ConstraintMakerExtendable {
        self.description.attributes += .trailing
        return self
    }
    
    public var width: ConstraintMakerExtendable {
        self.description.attributes += .width
        return self
    }
    
    public var height: ConstraintMakerExtendable {
        self.description.attributes += .height
        return self
    }
    
    public var centerX: ConstraintMakerExtendable {
        self.description.attributes += .centerX
        return self
    }
    
    public var centerY: ConstraintMakerExtendable {
        self.description.attributes += .centerY
        return self
    }
    
    @available(*, deprecated, renamed:"lastBaseline")
    public var baseline: ConstraintMakerExtendable {
        self.description.attributes += .lastBaseline
        return self
    }
    
    public var lastBaseline: ConstraintMakerExtendable {
        self.description.attributes += .lastBaseline
        return self
    }
    
    @available(iOS 8.0, OSX 10.11, *)
    public var firstBaseline: ConstraintMakerExtendable {
        self.description.attributes += .firstBaseline
        return self
    }
    
    @available(iOS 8.0, *)
    public var leftMargin: ConstraintMakerExtendable {
        self.description.attributes += .leftMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var rightMargin: ConstraintMakerExtendable {
        self.description.attributes += .rightMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var topMargin: ConstraintMakerExtendable {
        self.description.attributes += .topMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var bottomMargin: ConstraintMakerExtendable {
        self.description.attributes += .bottomMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var leadingMargin: ConstraintMakerExtendable {
        self.description.attributes += .leadingMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var trailingMargin: ConstraintMakerExtendable {
        self.description.attributes += .trailingMargin
        return self
    }
    
    @available(iOS 8.0, *)
    public var centerXWithinMargins: ConstraintMakerExtendable {
        self.description.attributes += .centerXWithinMargins
        return self
    }
    
    @available(iOS 8.0, *)
    public var centerYWithinMargins: ConstraintMakerExtendable {
        self.description.attributes += .centerYWithinMargins
        return self
    }
    
    public var edges: ConstraintMakerExtendable {
        self.description.attributes += .edges
        return self
    }
    public var horizontalEdges: ConstraintMakerExtendable {
        self.description.attributes += .horizontalEdges
        return self
    }
    public var verticalEdges: ConstraintMakerExtendable {
        self.description.attributes += .verticalEdges
        return self
    }
    public var directionalEdges: ConstraintMakerExtendable {
        self.description.attributes += .directionalEdges
        return self
    }
    public var directionalHorizontalEdges: ConstraintMakerExtendable {
        self.description.attributes += .directionalHorizontalEdges
        return self
    }
    public var directionalVerticalEdges: ConstraintMakerExtendable {
        self.description.attributes += .directionalVerticalEdges
        return self
    }
    public var size: ConstraintMakerExtendable {
        self.description.attributes += .size
        return self
    }
    
    @available(iOS 8.0, *)
    public var margins: ConstraintMakerExtendable {
        self.description.attributes += .margins
        return self
    }
    
    @available(iOS 8.0, *)
    public var directionalMargins: ConstraintMakerExtendable {
      self.description.attributes += .directionalMargins
      return self
    }

    @available(iOS 8.0, *)
    public var centerWithinMargins: ConstraintMakerExtendable {
        self.description.attributes += .centerWithinMargins
        return self
    }
    
}
