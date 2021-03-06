#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

public class ConstraintMaker {
    
    public var left: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.left)
    }
    
    public var top: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.top)
    }
    
    public var bottom: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.bottom)
    }
    
    public var right: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.right)
    }
    
    public var leading: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.leading)
    }
    
    public var trailing: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.trailing)
    }
    
    public var width: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.width)
    }
    
    public var height: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.height)
    }
    
    public var centerX: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.centerX)
    }
    
    public var centerY: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.centerY)
    }
    
    @available(*, deprecated, renamed:"lastBaseline")
    public var baseline: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.lastBaseline)
    }
    
    public var lastBaseline: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.lastBaseline)
    }
    
    @available(iOS 8.0, OSX 10.11, *)
    public var firstBaseline: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.firstBaseline)
    }
    
    @available(iOS 8.0, *)
    public var leftMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.leftMargin)
    }
    
    @available(iOS 8.0, *)
    public var rightMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.rightMargin)
    }
    
    @available(iOS 8.0, *)
    public var topMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.topMargin)
    }
    
    @available(iOS 8.0, *)
    public var bottomMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.bottomMargin)
    }
    
    @available(iOS 8.0, *)
    public var leadingMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.leadingMargin)
    }
    
    @available(iOS 8.0, *)
    public var trailingMargin: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.trailingMargin)
    }
    
    @available(iOS 8.0, *)
    public var centerXWithinMargins: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.centerXWithinMargins)
    }
    
    @available(iOS 8.0, *)
    public var centerYWithinMargins: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.centerYWithinMargins)
    }
    
    public var edges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.edges)
    }
    public var horizontalEdges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.horizontalEdges)
    }
    public var verticalEdges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.verticalEdges)
    }
    public var directionalEdges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.directionalEdges)
    }
    public var directionalHorizontalEdges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.directionalHorizontalEdges)
    }
    public var directionalVerticalEdges: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.directionalVerticalEdges)
    }
    public var size: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.size)
    }
    public var center: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.center)
    }
    
    @available(iOS 8.0, *)
    public var margins: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.margins)
    }
    
    @available(iOS 8.0, *)
    public var directionalMargins: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.directionalMargins)
    }

    @available(iOS 8.0, *)
    public var centerWithinMargins: ConstraintMakerExtendable {
        return self.makeExtendableWithAttributes(.centerWithinMargins)
    }
    
    // 创建一个 ConstraintDescription, 作为数据的盒子, 加到自己的 descriptions 内
    // 然后后续的 ConstraintMakerExtendable 的各种操作, 是向 ConstraintDescription 盒子里面添加数据.
    internal func makeExtendableWithAttributes(_ attributes: ConstraintAttributes) -> ConstraintMakerExtendable {
        let description = ConstraintDescription(item: self.item, attributes: attributes)
        self.descriptions.append(description)
        return ConstraintMakerExtendable(description)
    }
    
    private let item: LayoutConstraintItem
    private var descriptions = [ConstraintDescription]()
    
    // 上面的各种属性, 就是 Closure 里面, 面向程序员的接口;
    
    
    
    internal init(item: LayoutConstraintItem) {
        self.item = item
        self.item.prepare()
    }
    
    
    internal static func prepareConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        let maker = ConstraintMaker(item: item)
        // 这里, 就是常用的 make 闭包. 传入了就是一个 ConstraintMaker
        closure(maker)
        
        // maker 里面, 不断的收集, 在 closure 里面添加到 item 上面的 constraint.
        var constraints: [Constraint] = []
        for description in maker.descriptions {
            guard let constraint = description.constraint else {
                continue
            }
            constraints.append(constraint)
        }
        return constraints
    }
    
    // makeConstraints 使用的是 activateIfNeeded(false)
    // 只会将新生成的约束添加到 View 上, 不过影响之前的布局.
    // 所以可能会产生冲突.
    internal static func makeConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        let constraints = prepareConstraints(item: item, closure: closure)
        for constraint in constraints {
            constraint.activateIfNeeded(updatingExisting: false)
        }
    }
    
    // remake 在进行新的 constraint 的设置之前, 会将 item 原有的 Constraint 都进行删除.
    // 这种删除, 是建立在
    internal static func remakeConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        self.removeConstraints(item: item)
        self.makeConstraints(item: item, closure: closure)
    }
    
    internal static func updateConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        // 如果, 当前 Item 上面, 没有添加过约束, 直接按照初始化处理就好了.
        guard item.constraints.count > 0 else {
            self.makeConstraints(item: item, closure: closure)
            return
        }
        
        /*
            通过新生成的约束, 去更新已有的约束.
            在这个过程中, 只会修改 constant 的值.
            所有, updateConstraints 里面, 不应该是设置新的约束, 而是修改原有约束的值.
            如果想要用新的约束, 来影响 View, 应该使用的是 ReMakeConstraints.
         */
        let constraints = prepareConstraints(item: item, closure: closure)
        for constraint in constraints {
            constraint.activateIfNeeded(updatingExisting: true)
        }
    }
    
    /*
        RemoveConstraints 会删除, 所有之前通过 Snapkit 设置的约束.
     
        Item.constraints 记录的是通过 SnapKit 添加到 View 上的约束.
        所以用 Xib 设置的约束, 不会在这里.
        使用 removeConstraints 来修改 Xib 产生的 View 是没有效果的.
     */
    internal static func removeConstraints(item: LayoutConstraintItem) {
        let constraints = item.constraints
        for constraint in constraints {
            constraint.deactivateIfNeeded()
        }
    }
    
}
