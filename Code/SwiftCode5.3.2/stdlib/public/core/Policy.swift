/// The return type of functions that do not return normally, that is, a type
/// with no values.
///
/// Use `Never` as the return type when declaring a closure, function, or
/// method that unconditionally throws an error, traps, or otherwise does
/// not terminate.
///
///     func crashAndBurn() -> Never {
///         fatalError("Something very, very bad happened")
///     }
@frozen
public enum Never {}

extension Never: Error {}

extension Never: Equatable, Comparable, Hashable {}

// 所有的函数, 都会有一个返回值.
// 正因为如此, 才能执行 optinal chain 等操作.
public typealias Void = ()

public typealias Float32 = Float
public typealias Float64 = Double

//===----------------------------------------------------------------------===//
// Default types for unconstrained literals
//===----------------------------------------------------------------------===//
/// The default type for an otherwise-unconstrained integer literal.
public typealias IntegerLiteralType = Int
/// The default type for an otherwise-unconstrained floating point literal.
public typealias FloatLiteralType = Double

/// The default type for an otherwise-unconstrained Boolean literal.
///
/// When you create a constant or variable using one of the Boolean literals
/// `true` or `false`, the resulting type is determined by the
/// `BooleanLiteralType` alias. For example:
///
///     let isBool = true
///     print("isBool is a '\(type(of: isBool))'")
///     // Prints "isBool is a 'Bool'"
///
/// The type aliased by `BooleanLiteralType` must conform to the
/// `ExpressibleByBooleanLiteral` protocol.
public typealias BooleanLiteralType = Bool

/// The default type for an otherwise-unconstrained unicode scalar literal.
public typealias UnicodeScalarType = String
/// The default type for an otherwise-unconstrained Unicode extended
/// grapheme cluster literal.
public typealias ExtendedGraphemeClusterType = String
/// The default type for an otherwise-unconstrained string literal.
public typealias StringLiteralType = String

//===----------------------------------------------------------------------===//
// Default types for unconstrained number literals
//===----------------------------------------------------------------------===//
#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
public typealias _MaxBuiltinFloatType = Builtin.FPIEEE80
#else
public typealias _MaxBuiltinFloatType = Builtin.FPIEEE64
#endif

//===----------------------------------------------------------------------===//
// Standard protocols
//===----------------------------------------------------------------------===//

#if _runtime(_ObjC)
public typealias AnyObject = Builtin.AnyObject
#else
public typealias AnyObject = Builtin.AnyObject
#endif

public typealias AnyClass = AnyObject.Type

// case 的默认行为, 就是相等性的判断.
public func ~= <T: Equatable>(a: T, b: T) -> Bool {
  return a == b
}

//===----------------------------------------------------------------------===//
// Standard precedence groups
//===----------------------------------------------------------------------===//

precedencegroup AssignmentPrecedence {
  assignment: true
  associativity: right
}
precedencegroup FunctionArrowPrecedence {
  associativity: right
  higherThan: AssignmentPrecedence
}
precedencegroup TernaryPrecedence {
  associativity: right
  higherThan: FunctionArrowPrecedence
}
precedencegroup DefaultPrecedence {
  higherThan: TernaryPrecedence
}
precedencegroup LogicalDisjunctionPrecedence {
  associativity: left
  higherThan: TernaryPrecedence
}
precedencegroup LogicalConjunctionPrecedence {
  associativity: left
  higherThan: LogicalDisjunctionPrecedence
}
precedencegroup ComparisonPrecedence {
  higherThan: LogicalConjunctionPrecedence
}
precedencegroup NilCoalescingPrecedence {
  associativity: right
  higherThan: ComparisonPrecedence
}
precedencegroup CastingPrecedence {
  higherThan: NilCoalescingPrecedence
}
precedencegroup RangeFormationPrecedence {
  higherThan: CastingPrecedence
}
precedencegroup AdditionPrecedence {
  associativity: left
  higherThan: RangeFormationPrecedence
}
precedencegroup MultiplicationPrecedence {
  associativity: left
  higherThan: AdditionPrecedence
}
precedencegroup BitwiseShiftPrecedence {
  higherThan: MultiplicationPrecedence
}


//===----------------------------------------------------------------------===//
// Standard operators
//===----------------------------------------------------------------------===//

// Standard postfix operators.
postfix operator ++
postfix operator --
postfix operator ...: Comparable

// Optional<T> unwrapping operator is built into the compiler as a part of
// postfix expression grammar.
//
// postfix operator !

// Standard prefix operators.
prefix operator ++
prefix operator --
prefix operator !: Bool
prefix operator ~: BinaryInteger
prefix operator +: AdditiveArithmetic
prefix operator -: SignedNumeric
prefix operator ...: Comparable
prefix operator ..<: Comparable

// Standard infix operators.

// "Exponentiative"

infix operator  <<: BitwiseShiftPrecedence, BinaryInteger
infix operator &<<: BitwiseShiftPrecedence, FixedWidthInteger
infix operator  >>: BitwiseShiftPrecedence, BinaryInteger
infix operator &>>: BitwiseShiftPrecedence, FixedWidthInteger

// "Multiplicative"

infix operator   *: MultiplicationPrecedence, Numeric
infix operator  &*: MultiplicationPrecedence, FixedWidthInteger
infix operator   /: MultiplicationPrecedence, BinaryInteger, FloatingPoint
infix operator   %: MultiplicationPrecedence, BinaryInteger
infix operator   &: MultiplicationPrecedence, BinaryInteger

// "Additive"

infix operator   +: AdditionPrecedence, AdditiveArithmetic, String, Array, Strideable
infix operator  &+: AdditionPrecedence, FixedWidthInteger
infix operator   -: AdditionPrecedence, AdditiveArithmetic, Strideable
infix operator  &-: AdditionPrecedence, FixedWidthInteger
infix operator   |: AdditionPrecedence, BinaryInteger
infix operator   ^: AdditionPrecedence, BinaryInteger

// FIXME: is this the right precedence level for "..." ?
infix operator  ...: RangeFormationPrecedence, Comparable
infix operator  ..<: RangeFormationPrecedence, Comparable

// The cast operators 'as' and 'is' are hardcoded as if they had the
// following attributes:
// infix operator as: CastingPrecedence

// "Coalescing"

infix operator ??: NilCoalescingPrecedence

// "Comparative"

infix operator  <: ComparisonPrecedence, Comparable
infix operator  <=: ComparisonPrecedence, Comparable
infix operator  >: ComparisonPrecedence, Comparable
infix operator  >=: ComparisonPrecedence, Comparable
infix operator  ==: ComparisonPrecedence, Equatable
infix operator  !=: ComparisonPrecedence, Equatable
infix operator ===: ComparisonPrecedence
infix operator !==: ComparisonPrecedence
// FIXME: ~= will be built into the compiler.
infix operator  ~=: ComparisonPrecedence

// "Conjunctive"

infix operator &&: LogicalConjunctionPrecedence, Bool

// "Disjunctive"

infix operator ||: LogicalDisjunctionPrecedence, Bool

// User-defined ternary operators are not supported. The ? : operator is
// hardcoded as if it had the following attributes:
// operator ternary ? : : TernaryPrecedence

// User-defined assignment operators are not supported. The = operator is
// hardcoded as if it had the following attributes:
// infix operator =: AssignmentPrecedence

// Compound

infix operator   *=: AssignmentPrecedence, Numeric
infix operator  &*=: AssignmentPrecedence, FixedWidthInteger
infix operator   /=: AssignmentPrecedence, BinaryInteger
infix operator   %=: AssignmentPrecedence, BinaryInteger
infix operator   +=: AssignmentPrecedence, AdditiveArithmetic, String, Array, Strideable
infix operator  &+=: AssignmentPrecedence, FixedWidthInteger
infix operator   -=: AssignmentPrecedence, AdditiveArithmetic, Strideable
infix operator  &-=: AssignmentPrecedence, FixedWidthInteger
infix operator  <<=: AssignmentPrecedence, BinaryInteger
infix operator &<<=: AssignmentPrecedence, FixedWidthInteger
infix operator  >>=: AssignmentPrecedence, BinaryInteger
infix operator &>>=: AssignmentPrecedence, FixedWidthInteger
infix operator   &=: AssignmentPrecedence, BinaryInteger
infix operator   ^=: AssignmentPrecedence, BinaryInteger
infix operator   |=: AssignmentPrecedence, BinaryInteger

// Workaround for <rdar://problem/14011860> SubTLF: Default
// implementations in protocols.  Library authors should ensure
// that this operator never needs to be seen by end-users.  See
// test/Prototypes/GenericDispatch.swift for a fully documented
// example of how this operator is used, and how its use can be hidden
// from users.
infix operator ~>
