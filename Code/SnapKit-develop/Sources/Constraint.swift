#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif

/*
    这个类, 是和 NSLayoutConstaint 转化的桥梁.
    它是被 ConstraintDescription 生成的.
 */
public final class Constraint {
    
    internal let sourceLocation: (String, UInt)
    internal let label: String?
    
    private let from: ConstraintItem
    private let to: ConstraintItem
    private let relation: ConstraintRelation
    private let multiplier: ConstraintMultiplierTarget
    private var constant: ConstraintConstantTarget {
        didSet {
            self.updateConstantAndPriorityIfNeeded()
        }
    }
    private var priority: ConstraintPriorityTarget {
        didSet {
            self.updateConstantAndPriorityIfNeeded()
        }
    }
    public var layoutConstraints: [LayoutConstraint]
    
    public var isActive: Bool {
        set {
            if newValue {
                activate()
            }
            else {
                deactivate()
            }
        }
        
        get {
            for layoutConstraint in self.layoutConstraints {
                if layoutConstraint.isActive {
                    return true
                }
            }
            return false
        }
    }
    
    // MARK: Initialization
    
    // 在初始化的时候, 就将生成的约束, 添加到了自己的 layoutConstraints 里面
    internal init(from: ConstraintItem,
                  to: ConstraintItem,
                  relation: ConstraintRelation,
                  sourceLocation: (String, UInt),
                  label: String?,
                  multiplier: ConstraintMultiplierTarget,
                  constant: ConstraintConstantTarget,
                  priority: ConstraintPriorityTarget) {
        self.from = from // 来源: 哪个 View 的什么属性
        self.to = to // 目的: 哪个 View 的什么属性
        self.relation = relation // 有什么关系
        self.sourceLocation = sourceLocation
        self.label = label
        self.multiplier = multiplier // 因子多少
        self.constant = constant // 偏移多少
        self.priority = priority // 优先级多少
        self.layoutConstraints = [] // 最终生成 NSLayoutConstraint 的存储位置.
        
        // get attributes
        let layoutFromAttributes = self.from.attributes.layoutAttributes
        let layoutToAttributes = self.to.attributes.layoutAttributes
        
        // get layout from
        let layoutFrom = self.from.layoutConstraintItem!
        
        // get relation
        let layoutRelation = self.relation.layoutRelation
        
        for layoutFromAttribute in layoutFromAttributes {
            // get layout to attribute
            let layoutToAttribute: LayoutAttribute
            if layoutToAttributes.count > 0 {
                if self.from.attributes == .edges && self.to.attributes == .margins {
                    switch layoutFromAttribute {
                    case .left:
                        layoutToAttribute = .leftMargin
                    case .right:
                        layoutToAttribute = .rightMargin
                    case .top:
                        layoutToAttribute = .topMargin
                    case .bottom:
                        layoutToAttribute = .bottomMargin
                    default:
                        fatalError()
                    }
                } else if self.from.attributes == .margins && self.to.attributes == .edges {
                    switch layoutFromAttribute {
                    case .leftMargin:
                        layoutToAttribute = .left
                    case .rightMargin:
                        layoutToAttribute = .right
                    case .topMargin:
                        layoutToAttribute = .top
                    case .bottomMargin:
                        layoutToAttribute = .bottom
                    default:
                        fatalError()
                    }
                } else if self.from.attributes == .directionalEdges && self.to.attributes == .directionalMargins {
                    switch layoutFromAttribute {
                    case .leading:
                        layoutToAttribute = .leadingMargin
                    case .trailing:
                        layoutToAttribute = .trailingMargin
                    case .top:
                        layoutToAttribute = .topMargin
                    case .bottom:
                        layoutToAttribute = .bottomMargin
                    default:
                        fatalError()
                    }
                } else if self.from.attributes == .directionalMargins && self.to.attributes == .directionalEdges {
                    switch layoutFromAttribute {
                    case .leadingMargin:
                        layoutToAttribute = .leading
                    case .trailingMargin:
                        layoutToAttribute = .trailing
                    case .topMargin:
                        layoutToAttribute = .top
                    case .bottomMargin:
                        layoutToAttribute = .bottom
                    default:
                        fatalError()
                    }
                } else if self.from.attributes == self.to.attributes {
                    layoutToAttribute = layoutFromAttribute
                } else {
                    layoutToAttribute = layoutToAttributes[0]
                }
            } else {
                if self.to.target == nil && (layoutFromAttribute == .centerX || layoutFromAttribute == .centerY) {
                    layoutToAttribute = layoutFromAttribute == .centerX ? .left : .top
                } else {
                    layoutToAttribute = layoutFromAttribute
                }
            }
            
            // get layout constant
            let layoutConstant: CGFloat = self.constant.constraintConstantTargetValueFor(layoutAttribute: layoutToAttribute)
            
            // get layout to
            var layoutTo: AnyObject? = self.to.target
            
            // use superview if possible
            if layoutTo == nil && layoutToAttribute != .width && layoutToAttribute != .height {
                layoutTo = layoutFrom.superview
            }
            
            // create layout constraint
            // 上面, 根据 ConstraintDescription 中存储的各种信息, 转化成为了 NSLayoutConstraint.
            let layoutConstraint = LayoutConstraint(
                item: layoutFrom,
                attribute: layoutFromAttribute,
                relatedBy: layoutRelation,
                toItem: layoutTo,
                attribute: layoutToAttribute,
                multiplier: self.multiplier.constraintMultiplierTargetValue,
                constant: layoutConstant
            )
            
            // set label
            layoutConstraint.label = self.label
            
            // set priority
            layoutConstraint.priority = LayoutPriority(rawValue: self.priority.constraintPriorityTargetValue)
            
            // set constraint
            layoutConstraint.constraint = self
            
            // append, 将系统的约束, 存储了起来.
            self.layoutConstraints.append(layoutConstraint)
        }
    }
    
    // MARK: Public
    
    @available(*, deprecated, renamed:"activate()")
    public func install() {
        self.activate()
    }
    
    @available(*, deprecated, renamed:"deactivate()")
    public func uninstall() {
        self.deactivate()
    }
    
    public func activate() {
        self.activateIfNeeded()
    }
    
    public func deactivate() {
        self.deactivateIfNeeded()
    }
    
    @discardableResult
    public func update(offset: ConstraintOffsetTarget) -> Constraint {
        self.constant = offset.constraintOffsetTargetValue
        return self
    }
    
    @discardableResult
    public func update(inset: ConstraintInsetTarget) -> Constraint {
        self.constant = inset.constraintInsetTargetValue
        return self
    }
    
    #if os(iOS) || os(tvOS)
    @discardableResult
    @available(iOS 11.0, tvOS 11.0, *)
    public func update(inset: ConstraintDirectionalInsetTarget) -> Constraint {
        self.constant = inset.constraintDirectionalInsetTargetValue
        return self
    }
    #endif
    
    @discardableResult
    public func update(priority: ConstraintPriorityTarget) -> Constraint {
        self.priority = priority.constraintPriorityTargetValue
        return self
    }
    
    @discardableResult
    public func update(priority: ConstraintPriority) -> Constraint {
        self.priority = priority.value
        return self
    }
    
    @available(*, deprecated, renamed:"update(offset:)")
    public func updateOffset(amount: ConstraintOffsetTarget) -> Void { self.update(offset: amount) }
    
    @available(*, deprecated, renamed:"update(inset:)")
    public func updateInsets(amount: ConstraintInsetTarget) -> Void { self.update(inset: amount) }
    
    @available(*, deprecated, renamed:"update(priority:)")
    public func updatePriority(amount: ConstraintPriorityTarget) -> Void { self.update(priority: amount) }
    
    @available(*, deprecated, message:"Use update(priority: ConstraintPriorityTarget) instead.")
    public func updatePriorityRequired() -> Void {}
    
    @available(*, deprecated, message:"Use update(priority: ConstraintPriorityTarget) instead.")
    public func updatePriorityHigh() -> Void { fatalError("Must be implemented by Concrete subclass.") }
    
    @available(*, deprecated, message:"Use update(priority: ConstraintPriorityTarget) instead.")
    public func updatePriorityMedium() -> Void { fatalError("Must be implemented by Concrete subclass.") }
    
    @available(*, deprecated, message:"Use update(priority: ConstraintPriorityTarget) instead.")
    public func updatePriorityLow() -> Void { fatalError("Must be implemented by Concrete subclass.") }
    
    // MARK: Internal
    
    internal func updateConstantAndPriorityIfNeeded() {
        for layoutConstraint in self.layoutConstraints {
            let attribute = (layoutConstraint.secondAttribute == .notAnAttribute) ? layoutConstraint.firstAttribute : layoutConstraint.secondAttribute
            layoutConstraint.constant = self.constant.constraintConstantTargetValueFor(layoutAttribute: attribute)
            
            let requiredPriority = ConstraintPriority.required.value
            if (layoutConstraint.priority.rawValue < requiredPriority), (self.priority.constraintPriorityTargetValue != requiredPriority) {
                layoutConstraint.priority = LayoutPriority(rawValue: self.priority.constraintPriorityTargetValue)
            }
        }
    }
    
    internal func activateIfNeeded(updatingExisting: Bool = false) {
        guard let item = self.from.layoutConstraintItem else {
            print("WARNING: SnapKit failed to get from item from constraint. Activate will be a no-op.")
            return
        }
        let layoutConstraints = self.layoutConstraints
        
        if updatingExisting {
            var existingLayoutConstraints: [LayoutConstraint] = []
            for constraint in item.constraints {
                existingLayoutConstraints += constraint.layoutConstraints
            }
            
            for layoutConstraint in layoutConstraints {
                let existingLayoutConstraint = existingLayoutConstraints.first { $0 == layoutConstraint }
                guard let updateLayoutConstraint = existingLayoutConstraint else {
                    fatalError("Updated constraint could not find existing matching constraint to update: \(layoutConstraint)")
                }
                
                let updateLayoutAttribute =
                    (updateLayoutConstraint.secondAttribute == .notAnAttribute) ? updateLayoutConstraint.firstAttribute : updateLayoutConstraint.secondAttribute
                updateLayoutConstraint.constant = self.constant.constraintConstantTargetValueFor(layoutAttribute: updateLayoutAttribute)
            }
        } else {
            NSLayoutConstraint.activate(layoutConstraints)
            item.add(constraints: [self])
        }
    }
    
    internal func deactivateIfNeeded() {
        guard let item = self.from.layoutConstraintItem else {
            print("WARNING: SnapKit failed to get from item from constraint. Deactivate will be a no-op.")
            return
        }
        let layoutConstraints = self.layoutConstraints
        NSLayoutConstraint.deactivate(layoutConstraints)
        item.remove(constraints: [self])
    }
}
