#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif

// Relatable 的意思是, 可以添加关系.
public class ConstraintMakerRelatable {
    
    internal let description: ConstraintDescription
    
    internal init(_ description: ConstraintDescription) {
        self.description = description
    }
    
    // 在这里, 进行了关系的确认.
    internal func relatedTo(_ other: ConstraintRelatableTarget,
                            relation: ConstraintRelation,
                            file: String,
                            line: UInt) -> ConstraintMakerEditable {
        
        let related: ConstraintItem
        let constant: ConstraintConstantTarget
        
        // ConstraintItem 指的是 other.bottom 这种形式.
        if let other = other as? ConstraintItem {
            guard other.attributes == ConstraintAttributes.none ||
                    other.attributes.layoutAttributes.count <= 1 ||
                    other.attributes.layoutAttributes == self.description.attributes.layoutAttributes ||
                    other.attributes == .edges && self.description.attributes == .margins ||
                    other.attributes == .margins && self.description.attributes == .edges ||
                    other.attributes == .directionalEdges && self.description.attributes == .directionalMargins ||
                    other.attributes == .directionalMargins && self.description.attributes == .directionalEdges else {
                fatalError("Cannot constraint to multiple non identical attributes. (\(file), \(line))");
            }
            
            related = other
            constant = 0.0
        } else if let other = other as? ConstraintView {
            related = ConstraintItem(target: other, attributes: ConstraintAttributes.none)
            constant = 0.0
        } else if let other = other as? ConstraintConstantTarget {
            // ConstraintConstantTarget 指的是 equealTo(20) 这种形式.
            related = ConstraintItem(target: nil, attributes: ConstraintAttributes.none)
            constant = other
        } else if #available(iOS 9.0, OSX 10.11, *), let other = other as? ConstraintLayoutGuide {
            related = ConstraintItem(target: other, attributes: ConstraintAttributes.none)
            constant = 0.0
        } else {
            fatalError("Invalid constraint. (\(file), \(line))")
        }
        
        
        // equalto 可以接受各种不同的类型, 原因在于
        // ConstraintRelatableTarget 是一个协议, 数字可以实现该协议, View 也可以实现该协议
        // 为了方便用户调用. 这个函数内, 再对类型, 做分化处理.
        let editable = ConstraintMakerEditable(self.description)
        editable.description.sourceLocation = (file, line)
        editable.description.relation = relation
        editable.description.related = related
        editable.description.constant = constant
        return editable
    }
    
    @discardableResult
    public func equalTo(_ other: ConstraintRelatableTarget,
                        _ file: String = #file,
                        _ line: UInt = #line) -> ConstraintMakerEditable {
        return self.relatedTo(other, relation: .equal, file: file, line: line)
    }
    
    // 各种 ToSuperView, 仅仅是省略了 targetItem 的书写而已.
    @discardableResult
    public func equalToSuperview(_ file: String = #file, _ line: UInt = #line) -> ConstraintMakerEditable {
        guard let other = self.description.item.superview else {
            fatalError("Expected superview but found nil when attempting make constraint `equalToSuperview`.")
        }
        return self.relatedTo(other, relation: .equal, file: file, line: line)
    }
    
    @discardableResult
    public func lessThanOrEqualTo(_ other: ConstraintRelatableTarget, _ file: String = #file, _ line: UInt = #line) -> ConstraintMakerEditable {
        return self.relatedTo(other, relation: .lessThanOrEqual, file: file, line: line)
    }
    
    @discardableResult
    public func lessThanOrEqualToSuperview(_ file: String = #file, _ line: UInt = #line) -> ConstraintMakerEditable {
        guard let other = self.description.item.superview else {
            fatalError("Expected superview but found nil when attempting make constraint `lessThanOrEqualToSuperview`.")
        }
        return self.relatedTo(other, relation: .lessThanOrEqual, file: file, line: line)
    }
    
    @discardableResult
    public func greaterThanOrEqualTo(_ other: ConstraintRelatableTarget, _ file: String = #file, line: UInt = #line) -> ConstraintMakerEditable {
        return self.relatedTo(other, relation: .greaterThanOrEqual, file: file, line: line)
    }
    
    @discardableResult
    public func greaterThanOrEqualToSuperview(_ file: String = #file, line: UInt = #line) -> ConstraintMakerEditable {
        guard let other = self.description.item.superview else {
            fatalError("Expected superview but found nil when attempting make constraint `greaterThanOrEqualToSuperview`.")
        }
        return self.relatedTo(other, relation: .greaterThanOrEqual, file: file, line: line)
    }
}
