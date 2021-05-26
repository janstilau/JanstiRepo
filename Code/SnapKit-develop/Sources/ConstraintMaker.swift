#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

public class ConstraintMaker {
    
    
    /*
        Maker 的各种 left, right, 其实是传递一个新的对象出去. 在这个对象上, 进行各种配置工作.
     */
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
    
    
    
    
    private let item: LayoutConstraintItem // View, Layout, LayoutGuide
    // ConstraintDescription 是一个引用类型, 在 make.left.right 的过程中, 不断的修改里面的值.
    // make {} 里面, make.left....; make.right....
    // 每一次 make 语句, 都是向 descriptions 添加一个引用值, 然后在链式调用, 就是不断的修改这个引用值的内容而已.
    // 这种写法很常见, 例如, alamofire 里面, 各种 .response, .progress 其实都是修改 data_request 里面的属性而已.
    // 最后, 网络请求的时候, 才会去读取这些属性, 然后进行网络回调的触发.
    private var descriptions = [ConstraintDescription]()
    
    internal init(item: LayoutConstraintItem) {
        self.item = item
        self.item.prepare()
    }
    
    // 创建一个引用对象, 自己存储一下, 然后把这个引用对象丢到调用链里面不断的进行修改.
    // 一个盒子, 不断的在过程里面进行数据的添加修改.
    // 最后才去拿这个盒子进行真正的业务操作.
    internal func makeExtendableWithAttributes(_ attributes: ConstraintAttributes) -> ConstraintMakerExtendable {
        let description = ConstraintDescription(item: self.item, attributes: attributes)
        self.descriptions.append(description)
        return ConstraintMakerExtendable(description)
    }
    
    
    
    
    /*
         v1.snp.makeConstraints { (make) -> Void in
             make.top.equalTo(v2).offset(50)
             make.left.equalTo(v2).offset(50)
             return
         }
        上面, make 调用一次, 就是给自己添加一条 description 而已
     */
    
    
    internal static func prepareConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        
        let maker = ConstraintMaker(item: item)
        closure(maker)
        var constraints: [Constraint] = []
        
        // closure(maker) 的主要功能, 就是将各种对于约束的描述, 添加到了 maker.descriptions 里面.
        
        for description in maker.descriptions {
            // description.constraint 的调用过程, 就是不断地生成 Constraint 的过程.
            guard let constraint = description.constraint else {
                continue
            }
            constraints.append(constraint)
        }
        return constraints
    }
    
    // 使用类方法, 将对象的创建工作, 封装到了各个类方法的内部.
    // 对象, 就是完成操作的工具. 在使用完只有, 释放就可以了
    internal static func makeConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        let constraints = prepareConstraints(item: item, closure: closure)
        for constraint in constraints {
            constraint.activateIfNeeded(updatingExisting: false)
        }
    }
    
    internal static func remakeConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        self.removeConstraints(item: item)
        self.makeConstraints(item: item, closure: closure)
    }
    
    internal static func updateConstraints(item: LayoutConstraintItem, closure: (_ make: ConstraintMaker) -> Void) {
        guard item.constraints.count > 0 else {
            self.makeConstraints(item: item, closure: closure)
            return
        }
        
        let constraints = prepareConstraints(item: item, closure: closure)
        for constraint in constraints {
            constraint.activateIfNeeded(updatingExisting: true)
        }
    }
    
    internal static func removeConstraints(item: LayoutConstraintItem) {
        let constraints = item.constraints
        for constraint in constraints {
            constraint.deactivateIfNeeded()
        }
    }
    
}
