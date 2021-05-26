//
//  SnapKit
//
//  Copyright (c) 2011-Present SnapKit Team - https://github.com/SnapKit
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif


public class ConstraintMakerRelatable {
    
    internal let description: ConstraintDescription
    
    internal init(_ description: ConstraintDescription) {
        self.description = description
    }
    
    /*
        逻辑集中在一处进行处理.
     */
    internal func relatedTo(_ other: ConstraintRelatableTarget,
                            relation: ConstraintRelation,
                            file: String, line: UInt) -> ConstraintMakerEditable {
        let related: ConstraintItem
        let constant: ConstraintConstantTarget
        
        // 在这里, 确定了 target 的值
        if let other = other as? ConstraintItem {
            
            // to 是一个 item, 就是 view.left, view.top 这种.
            // 直接使用 to 的 target, attribute.
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
            // to 是一个 View, 那么 to 的 attribute 就是 none, 最后也就是使用 from 的 attribute
            related = ConstraintItem(target: other, attributes: ConstraintAttributes.none)
            constant = 0.0
        } else if let other = other as? ConstraintConstantTarget {
            // to 是一个值, 没有 target, 就应该是 width, height 这种不需要 target 的
            related = ConstraintItem(target: nil, attributes: ConstraintAttributes.none)
            constant = other
        } else if #available(iOS 9.0, OSX 10.11, *), let other = other as? ConstraintLayoutGuide {
            related = ConstraintItem(target: other, attributes: ConstraintAttributes.none)
            constant = 0.0
        } else {
            fatalError("Invalid constraint. (\(file), \(line))")
        }
        
        /*
            当 Extendable 进行了各种属性的叠加之后, 调用了 equal to 才会生成 ConstraintMakerEditable, 表示应该进行数值的操作了.
            ConstraintMakerEditable 里面是, 乘法, offset, 以及 priority 的修改.
         */
        
        let editable = ConstraintMakerEditable(self.description)
        editable.description.sourceLocation = (file, line)
        editable.description.relation = relation
        editable.description.related = related
        editable.description.constant = constant
        return editable
    }
    
    
    /*
        left.right.leading 是向 attributes 里面, 添加数据.
        而 下面的各种方法, 是向 desciption 的 item 添加数据.
     */
    
    @discardableResult
    public func equalTo(_ other: ConstraintRelatableTarget, _ file: String = #file, _ line: UInt = #line) -> ConstraintMakerEditable {
        return self.relatedTo(other, relation: .equal, file: file, line: line)
    }
    
    @discardableResult
    public func equalToSuperview(_ file: String = #file, _ line: UInt = #line) -> ConstraintMakerEditable {
        // equalToSuperview 其实, 就是省略了取值 other 的过程.
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
