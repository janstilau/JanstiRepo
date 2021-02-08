import SwiftShims

extension StringProtocol {
    @inlinable
    @_specialize(where Self == String, RHS == String)
    @_specialize(where Self == String, RHS == Substring)
    @_specialize(where Self == Substring, RHS == String)
    @_specialize(where Self == Substring, RHS == Substring)
    @_effects(readonly)
    public static func == <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return _stringCompare(
            lhs._wholeGuts, lhs._offsetRange,
            rhs._wholeGuts, rhs._offsetRange,
            expecting: .equal)
    }
    
    @inlinable @inline(__always) // forward to other operator
    @_effects(readonly)
    public static func != <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return !(lhs == rhs)
    }
    
    @inlinable
    @_specialize(where Self == String, RHS == String)
    @_specialize(where Self == String, RHS == Substring)
    @_specialize(where Self == Substring, RHS == String)
    @_specialize(where Self == Substring, RHS == Substring)
    @_effects(readonly)
    public static func < <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return _stringCompare(
            lhs._wholeGuts, lhs._offsetRange,
            rhs._wholeGuts, rhs._offsetRange,
            expecting: .less)
    }
    
    @inlinable @inline(__always) // forward to other operator
    @_effects(readonly)
    public static func > <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return rhs < lhs
    }
    
    @inlinable @inline(__always) // forward to other operator
    @_effects(readonly)
    public static func <= <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return !(rhs < lhs)
    }
    
    public static func >= <RHS: StringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        return !(lhs < rhs)
    }
}

extension String: Equatable {
    public static func == (lhs: String, rhs: String) -> Bool {
        return _stringCompare(lhs._guts, rhs._guts, expecting: .equal)
    }
}

extension String: Comparable {
    public static func < (lhs: String, rhs: String) -> Bool {
        return _stringCompare(lhs._guts, rhs._guts, expecting: .less)
    }
}

extension Substring: Equatable {}
extension String {
    public static func ~= (lhs: String, rhs: Substring) -> Bool {
        return lhs == rhs
    }
}
extension Substring {
    public static func ~= (lhs: Substring, rhs: String) -> Bool {
        return lhs == rhs
    }
}


