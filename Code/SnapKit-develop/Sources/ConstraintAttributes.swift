#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

// OptionSet 这个值, 就当做是 Int 的位运算操作的封装就好了

internal struct ConstraintAttributes : OptionSet, ExpressibleByIntegerLiteral {
    
    typealias IntegerLiteralType = UInt
    
    internal init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    internal init(_ rawValue: UInt) {
        self.init(rawValue: rawValue)
    }
    internal init(nilLiteral: ()) {
        self.rawValue = 0
    }
    internal init(integerLiteral rawValue: IntegerLiteralType) {
        self.init(rawValue: rawValue)
    }
    
    internal private(set) var rawValue: UInt
    internal static var allZeros: ConstraintAttributes { return 0 }
    internal static func convertFromNilLiteral() -> ConstraintAttributes { return 0 }
    internal var boolValue: Bool { return self.rawValue != 0 }
    
    internal func toRaw() -> UInt { return self.rawValue }
    internal static func fromRaw(_ raw: UInt) -> ConstraintAttributes? { return self.init(raw) }
    internal static func fromMask(_ raw: UInt) -> ConstraintAttributes { return self.init(raw) }
    
    // normal
    
    // 几个最最基本的, 最最常用的约束值
    internal static let none: ConstraintAttributes = 0
    internal static let left: ConstraintAttributes = ConstraintAttributes(UInt(1) << 0)
    internal static let top: ConstraintAttributes = ConstraintAttributes(UInt(1) << 1)
    internal static let right: ConstraintAttributes = ConstraintAttributes(UInt(1) << 2)
    internal static let bottom: ConstraintAttributes = ConstraintAttributes(UInt(1) << 3)
    internal static let leading: ConstraintAttributes = ConstraintAttributes(UInt(1) << 4)
    internal static let trailing: ConstraintAttributes = ConstraintAttributes(UInt(1) << 5)
    internal static let width: ConstraintAttributes = ConstraintAttributes(UInt(1) << 6)
    internal static let height: ConstraintAttributes = ConstraintAttributes(UInt(1) << 7)
    internal static let centerX: ConstraintAttributes = ConstraintAttributes(UInt(1) << 8)
    internal static let centerY: ConstraintAttributes = ConstraintAttributes(UInt(1) << 9)
    internal static let lastBaseline: ConstraintAttributes = ConstraintAttributes(UInt(1) << 10)
    
    @available(iOS 8.0, OSX 10.11, *)
    internal static let firstBaseline: ConstraintAttributes = ConstraintAttributes(UInt(1) << 11)

    @available(iOS 8.0, *)
    internal static let leftMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 12)

    @available(iOS 8.0, *)
    internal static let rightMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 13)

    @available(iOS 8.0, *)
    internal static let topMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 14)

    @available(iOS 8.0, *)
    internal static let bottomMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 15)

    @available(iOS 8.0, *)
    internal static let leadingMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 16)

    @available(iOS 8.0, *)
    internal static let trailingMargin: ConstraintAttributes = ConstraintAttributes(UInt(1) << 17)

    @available(iOS 8.0, *)
    internal static let centerXWithinMargins: ConstraintAttributes = ConstraintAttributes(UInt(1) << 18)

    @available(iOS 8.0, *)
    internal static let centerYWithinMargins: ConstraintAttributes = ConstraintAttributes(UInt(1) << 19)
    
    // aggregates
    
    // Edge 就是对于上下左右的封装.
    internal static let edges: ConstraintAttributes = [.horizontalEdges, .verticalEdges]
    internal static let horizontalEdges: ConstraintAttributes = [.left, .right]
    
    internal static let verticalEdges: ConstraintAttributes = [.top, .bottom]
    internal static let directionalEdges: ConstraintAttributes = [.directionalHorizontalEdges, .directionalVerticalEdges]
    internal static let directionalHorizontalEdges: ConstraintAttributes = [.leading, .trailing]
    internal static let directionalVerticalEdges: ConstraintAttributes = [.top, .bottom]
    internal static let size: ConstraintAttributes = [.width, .height]
    internal static let center: ConstraintAttributes = [.centerX, .centerY]

    @available(iOS 8.0, *)
    internal static let margins: ConstraintAttributes = [.leftMargin, .topMargin, .rightMargin, .bottomMargin]

    @available(iOS 8.0, *)
    internal static let directionalMargins: ConstraintAttributes = [.leadingMargin, .topMargin, .trailingMargin, .bottomMargin]

    @available(iOS 8.0, *)
    internal static let centerWithinMargins: ConstraintAttributes = [.centerXWithinMargins, .centerYWithinMargins]
    
    // 一个计算属性, 就是从 optionSet 里面, 取值的过程
    internal var layoutAttributes:[LayoutAttribute] {
        var attrs = [LayoutAttribute]()
        if (self.contains(ConstraintAttributes.left)) {
            attrs.append(.left)
        }
        if (self.contains(ConstraintAttributes.top)) {
            attrs.append(.top)
        }
        if (self.contains(ConstraintAttributes.right)) {
            attrs.append(.right)
        }
        if (self.contains(ConstraintAttributes.bottom)) {
            attrs.append(.bottom)
        }
        if (self.contains(ConstraintAttributes.leading)) {
            attrs.append(.leading)
        }
        if (self.contains(ConstraintAttributes.trailing)) {
            attrs.append(.trailing)
        }
        if (self.contains(ConstraintAttributes.width)) {
            attrs.append(.width)
        }
        if (self.contains(ConstraintAttributes.height)) {
            attrs.append(.height)
        }
        if (self.contains(ConstraintAttributes.centerX)) {
            attrs.append(.centerX)
        }
        if (self.contains(ConstraintAttributes.centerY)) {
            attrs.append(.centerY)
        }
        if (self.contains(ConstraintAttributes.lastBaseline)) {
            attrs.append(.lastBaseline)
        }
        
        #if os(iOS) || os(tvOS)
            if (self.contains(ConstraintAttributes.firstBaseline)) {
                attrs.append(.firstBaseline)
            }
            if (self.contains(ConstraintAttributes.leftMargin)) {
                attrs.append(.leftMargin)
            }
            if (self.contains(ConstraintAttributes.rightMargin)) {
                attrs.append(.rightMargin)
            }
            if (self.contains(ConstraintAttributes.topMargin)) {
                attrs.append(.topMargin)
            }
            if (self.contains(ConstraintAttributes.bottomMargin)) {
                attrs.append(.bottomMargin)
            }
            if (self.contains(ConstraintAttributes.leadingMargin)) {
                attrs.append(.leadingMargin)
            }
            if (self.contains(ConstraintAttributes.trailingMargin)) {
                attrs.append(.trailingMargin)
            }
            if (self.contains(ConstraintAttributes.centerXWithinMargins)) {
                attrs.append(.centerXWithinMargins)
            }
            if (self.contains(ConstraintAttributes.centerYWithinMargins)) {
                attrs.append(.centerYWithinMargins)
            }
        #endif
        
        return attrs
    }
}


// 几个操作符, 进行 attribute 的数值的合并操作.
// 这个在 .left.right 这种链式调用里面使用了.
internal func + (left: ConstraintAttributes, right: ConstraintAttributes) -> ConstraintAttributes {
    return left.union(right)
}

internal func +=(left: inout ConstraintAttributes, right: ConstraintAttributes) {
    left.formUnion(right)
}

internal func -=(left: inout ConstraintAttributes, right: ConstraintAttributes) {
    left.subtract(right)
}

internal func ==(left: ConstraintAttributes, right: ConstraintAttributes) -> Bool {
    return left.rawValue == right.rawValue
}
