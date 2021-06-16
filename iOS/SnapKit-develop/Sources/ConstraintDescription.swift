#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif


// 一个数据盒子.
// 必须是引用类型, 这样, 各种 container 类才能使用自己的方法, 对 ConstraintDescription 的数据进行修改.
// 暴露出 constraint, 提供了 Description 数据类, 到实际的 Constraint 的转化.
public class ConstraintDescription {
    
    internal let item: LayoutConstraintItem // 可能是 View, 也可能是 layoutGuide
    internal var attributes: ConstraintAttributes
    internal var relation: ConstraintRelation? = nil
    internal var sourceLocation: (String, UInt)? = nil
    internal var label: String? = nil
    internal var related: ConstraintItem? = nil
    internal var multiplier: ConstraintMultiplierTarget = 1.0
    internal var constant: ConstraintConstantTarget = 0.0
    internal var priority: ConstraintPriorityTarget = 1000.0
    
    // 以上的信息, 在 closure 的每一行中, 其实都是将相关的数据, 收集到对应的成员属性里面.
    
    // 在调用 constraint 的时候, 是将对应的数据, 重新组织成为一个 Constraint 对象传递出去.
    internal lazy var constraint: Constraint? = {
        guard let relation = self.relation,
              let related = self.related,
              let sourceLocation = self.sourceLocation else {
            return nil
        }
        let from = ConstraintItem(target: self.item, attributes: self.attributes)
        
        return Constraint(
            from: from,
            to: related,
            relation: relation,
            sourceLocation: sourceLocation,
            label: self.label,
            multiplier: self.multiplier,
            constant: self.constant,
            priority: self.priority
        )
    }()
    
    // MARK: Initialization
    
    internal init(item: LayoutConstraintItem, attributes: ConstraintAttributes) {
        self.item = item
        self.attributes = attributes
    }
    
}
