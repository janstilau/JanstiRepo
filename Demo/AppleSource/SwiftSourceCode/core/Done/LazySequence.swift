//===--- LazySequence.swift -----------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A sequence on which normally-eager operations such as `map` and
/// `filter` are implemented lazily.
///
/// Lazy sequences can be used to avoid needless storage allocation
/// and computation, because they use an underlying sequence for
/// storage and compute their elements on demand.  For example,
///
///     [1, 2, 3].lazy.map { $0 * 2 }
///
/// is a sequence containing { `2`, `4`, `6` }.  Each time an element
/// of the lazy sequence is accessed, an element of the underlying
/// array is accessed and transformed by the closure.
///
/// Sequence operations taking closure arguments, such as `map` and
/// `filter`, are normally eager: they use the closure immediately and
/// return a new array.  Using the `lazy` property gives the standard
/// library explicit permission to store the closure and the sequence
/// in the result, and defer computation until it is needed.
///  这里讲的很明白, 作为 lazy sequence, 只有当访问到它的数据的时候,  才会进行相应数据的生成操作.
///
/// To add new lazy sequence operations, extend this protocol with
/// methods that return lazy wrappers that are themselves
/// `LazySequenceProtocol`s.  For example, given an eager `scan`
/// method defined as follows
///
///     extension Sequence {
///       /// Returns an array containing the results of
///       ///
///       ///   p.reduce(initial, nextPartialResult)
///       ///
///       /// for each prefix `p` of `self`, in order from shortest to
///       /// longest.  For example:
///       ///
///       ///     (1..<6).scan(0, +) // [0, 1, 3, 6, 10, 15]
///       ///
///       /// - Complexity: O(n)
///       func scan<ResultElement>(
///         _ initial: ResultElement,
///         _ nextPartialResult: (ResultElement, Element) -> ResultElement
///       ) -> [ResultElement] {
///         var result = [initial]
///         for x in self {
///           result.append(nextPartialResult(result.last!, x))
///         }
///         return result
///       }
///     }
///
/// we can build a sequence that lazily computes the elements in the
/// result of `scan`:
///
/// 作为一个 Lazy Iterator, 它存储了原有的Sequence 的 iterator. 存储了原有的值, 存储了原有值和新值操作的 block.
///     struct LazyScanIterator<Base: IteratorProtocol, ResultElement>
///       : IteratorProtocol {
///
///       var nextElement: ResultElement? // The next result of next().
///       var base: Base                  // The underlying iterator.
///       let nextPartialResult: (ResultElement, Base.Element) -> ResultElement
///
///       mutating func next() -> ResultElement? {
///         return nextElement.map { result in // 这里的 result, 是 nextElement 的 wrappedValue
///           nextElement = base.next().map { nextPartialResult(result, $0) } // 这里的 $0 是 base.next() 的 wrappedValue
///           return result
///         }
///       }
///     }
///
///
/*
 对于一个 LazyScanSequence 来说, 生成它的对象的时候, 仅仅是对于原始 sequence, iterator, 还有 transform 闭包的一份记录而已.
 它的值在 access 的过程中, 才会动态的生成. 利用的就是它之前记录的那几个值.
 Lazy 可以避免在创建的过程中进行计算.
*/
///     struct LazyScanSequence<Base: Sequence, ResultElement>
///       : LazySequenceProtocol // Chained operations on self are lazy, too
///     {
///       func makeIterator() -> LazyScanIterator<Base.Iterator, ResultElement> {
///         return LazyScanIterator(
///           nextElement: initial, base: base.makeIterator(),
///           nextPartialResult: nextPartialResult)
///       }
///       let initial: ResultElement
///       let base: Base
///       let nextPartialResult:
///         (ResultElement, Base.Element) -> ResultElement
///     }
///
/// and finally, we can give all lazy sequences a lazy `scan` method:
///     
///     extension LazySequenceProtocol {
///       /// Returns a sequence containing the results of
///       ///
///       ///   p.reduce(initial, nextPartialResult)
///       ///
///       /// for each prefix `p` of `self`, in order from shortest to
///       /// longest.  For example:
///       ///
///       ///     Array((1..<6).lazy.scan(0, +)) // [0, 1, 3, 6, 10, 15]
///       ///
///       /// - Complexity: O(1)
///       func scan<ResultElement>(
///         _ initial: ResultElement,
///         _ nextPartialResult: @escaping (ResultElement, Element) -> ResultElement
///       ) -> LazyScanSequence<Self, ResultElement> {
///         return LazyScanSequence(
///           initial: initial, base: self, nextPartialResult: nextPartialResult)
///       }
///     }
///
/// - See also: `LazySequence`
///
/// - Note: The explicit permission to implement further operations
///   lazily applies only in contexts where the sequence is statically
///   known to conform to `LazySequenceProtocol`.  Thus, side-effects such
///   as the accumulation of `result` below are never unexpectedly
///   dropped or deferred:
///
///       extension Sequence where Element == Int {
///         func sum() -> Int {
///           var result = 0
///           _ = self.map { result += $0 }
///           return result
///         }
///       }
///
///   [We don't recommend that you use `map` this way, because it
///   creates and discards an array. `sum` would be better implemented
///   using `reduce`].

/*
 LazySequenceProtocol : Sequence
 标明, LazySequenceProtocol 的使用方式要完全和 Sequence 相同的.
 它的 primitiveMethod 里面, 没有任何对于能力的要求.
 */
public protocol LazySequenceProtocol: Sequence {
  /// A `Sequence` that can contain the same elements as this one,
  /// possibly with a simpler type.
  ///
  /// - See also: `elements`
  associatedtype Elements: Sequence = Self where Elements.Element == Element

  /// A sequence containing the same elements as this one, possibly with
  /// a simpler type.
  ///
  /// When implementing lazy operations, wrapping `elements` instead
  /// of `self` can prevent result types from growing an extra
  /// `LazySequence` layer.  For example,
  ///
  /// _prext_ example needed
  ///
  /// Note: this property need not be implemented by conforming types,
  /// it has a default implementation in a protocol extension that
  /// just returns `self`.
  var elements: Elements { get }
}

/// When there's no special associated `Elements` type, the `elements`
/// property is provided.
extension LazySequenceProtocol where Elements == Self {
  /// Identical to `self`.
  @inlinable // protocol-only
  public var elements: Self { return self }
}

extension LazySequenceProtocol {
  @inlinable // protocol-only
  public var lazy: LazySequence<Elements> {
    return elements.lazy
  }
}

extension LazySequenceProtocol where Elements: LazySequenceProtocol {
  @inlinable // protocol-only
  public var lazy: Elements {
    return elements
  }
}

/// A sequence containing the same elements as a `Base` sequence, but
/// on which some operations such as `map` and `filter` are
/// implemented lazily.
///
///
/// - See also: `LazySequenceProtocol`
/*
 Lazy, 首先要记录原来的 sequence.
 */
@frozen // lazy-performance
public struct LazySequence<Base: Sequence> {
  @usableFromInline
  internal var _base: Base

  /// Creates a sequence that has the same elements as `base`, but on
  /// which some operations such as `map` and `filter` are implemented
  /// lazily.
  @inlinable // lazy-performance
  internal init(_base: Base) {
    self._base = _base
  }
}

extension LazySequence: Sequence {
  public typealias Element = Base.Element
  public typealias Iterator = Base.Iterator

  @inlinable
  public __consuming func makeIterator() -> Iterator {
    return _base.makeIterator()
  }
  
  @inlinable // lazy-performance
  public var underestimatedCount: Int {
    return _base.underestimatedCount
  }

  @inlinable // lazy-performance
  @discardableResult
  public __consuming func _copyContents(
    initializing buf: UnsafeMutableBufferPointer<Element>
  ) -> (Iterator, UnsafeMutableBufferPointer<Element>.Index) {
    return _base._copyContents(initializing: buf)
  }

  @inlinable // lazy-performance
  public func _customContainsEquatableElement(_ element: Element) -> Bool? { 
    return _base._customContainsEquatableElement(element)
  }
  
  @inlinable // generic-performance
  public __consuming func _copyToContiguousArray() -> ContiguousArray<Element> {
    return _base._copyToContiguousArray()
  }
}

extension LazySequence: LazySequenceProtocol {
  public typealias Elements = Base

  /// The `Base` (presumably non-lazy) sequence from which `self` was created.
  @inlinable // lazy-performance
  public var elements: Elements { return _base }
}

extension Sequence {
  /// A sequence containing the same elements as this sequence,
  /// but on which some operations, such as `map` and `filter`, are
  /// implemented lazily.
  @inlinable // protocol-only
  public var lazy: LazySequence<Self> {
    return LazySequence(_base: self)
  }
}

/*
 整个文件里面, 没有说明 lazy 的具体的实现思路是什么.
 Lazy 到底怎么变得 lazy, 是各个开发人员, 根据自己的业务需求, 自己实现的.
 注释中, 有一个 lazy Scan 的实现方式.
 基本的实现思路是, 在 lazySequence 的 iterator 立马, next 除了访问baseIterator的 next 的返回结果以外, 还要对于返回结果进行一次操作.
 而这个操作, 是迭代的过程中才生产出来的.
 也就是说, 生产一个 lazySequence, 附带相应的 block 操作, 不会立马进行 block 的调用.
 这个各个 drop, Suffix sequence 的操作是一样的. 都是通过 baseiterator 进行取值, 只是在这个取值的过程中, 进行了自定义.
 */
