/// To add a new lazy sequence operation, extend this protocol with
/// a method that returns a lazy wrapper that itself conforms to
/// `LazySequenceProtocol`.  For example, an eager `scan(_:_:)`
/// method is defined as follows:
///
///     extension Sequence {
///         /// Returns an array containing the results of
///         ///
///         ///   p.reduce(initial, nextPartialResult)
///         ///
///         /// for each prefix `p` of `self`, in order from shortest to
///         /// longest. For example:
///         ///
///         ///     (1..<6).scan(0, +) // [0, 1, 3, 6, 10, 15]
///         ///
///         /// - Complexity: O(n)
///         func scan<Result>(
///             _ initial: Result,
///             _ nextPartialResult: (Result, Element) -> Result
///         ) -> [Result] {
///             var result = [initial]
///             for x in self {
///                 result.append(nextPartialResult(result.last!, x))
///             }
///             return result
///         }
///     }
///
/// You can build a sequence type that lazily computes the elements in the
/// result of a scan:
///
///     struct LazyScanSequence<Base: Sequence, Result>
///         : LazySequenceProtocol
///     {
///         let initial: Result
///         let base: Base
///         let nextPartialResult:
///             (Result, Base.Element) -> Result
///
///         struct Iterator: IteratorProtocol {
///             var base: Base.Iterator
///             var nextElement: Result?
///             let nextPartialResult:
///                 (Result, Base.Element) -> Result
///             
///             mutating func next() -> Result? {
///                 return nextElement.map { result in
///                     nextElement = base.next().map {
///                         nextPartialResult(result, $0)
///                     }
///                     return result
///                 }
///             }
///         }
///         
///         func makeIterator() -> Iterator {
///             return Iterator(
///                 base: base.makeIterator(),
///                 nextElement: initial as Result?,
///                 nextPartialResult: nextPartialResult)
///         }
///     }
///
/// Finally, you can give all lazy sequences a lazy `scan(_:_:)` method:
///     
///     extension LazySequenceProtocol {
///         func scan<Result>(
///             _ initial: Result,
///             _ nextPartialResult: @escaping (Result, Element) -> Result
///         ) -> LazyScanSequence<Self, Result> {
///             return LazyScanSequence(
///                 initial: initial, base: self, nextPartialResult: nextPartialResult)
///         }
///     }
///
/// With this type and extension method, you can call `.lazy.scan(_:_:)` on any
/// sequence to create a lazily computed scan. The resulting `LazyScanSequence`
/// is itself lazy, too, so further sequence operations also defer computation.
///
/// The explicit permission to implement operations lazily applies 
/// only in contexts where the sequence is statically known to conform to
/// `LazySequenceProtocol`. In the following example, because the extension 
/// applies only to `Sequence`, side-effects such as the accumulation of
/// `result` are never unexpectedly dropped or deferred:
///
///     extension Sequence where Element == Int {
///         func sum() -> Int {
///             var result = 0
///             _ = self.map { result += $0 }
///             return result
///         }
///     }
///
/// Don't actually use `map` for this purpose, however, because it creates 
/// and discards the resulting array. Instead, use `reduce` for summing 
/// operations, or `forEach` or a `for`-`in` loop for operations with side 
/// effects.
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

// 如果, 已经 element 已经是 LazySequenceProtocol, 直接返回 elements
extension LazySequenceProtocol where Elements: LazySequenceProtocol {
    @inlinable // protocol-only
    public var lazy: Elements {
        return elements
    }
}







// LazySequence 最最重要的, 他存有原有的 sequence, 也就是数据的源头.
// 它是 LazySequenceProtocol 的, 也就能够调用 LazySequenceProtocol 上定义的各种方法.
public struct LazySequence<Base: Sequence> {
    internal var _base: Base
    internal init(_base: Base) {
        self._base = _base
    }
}

// LazySequence 对于 Sequence 的各种实现, 都是转交给 _base 来了.
extension LazySequence: Sequence {
    public typealias Element = Base.Element
    public typealias Iterator = Base.Iterator
    public __consuming func makeIterator() -> Iterator {
        return _base.makeIterator()
    }
    public var underestimatedCount: Int {
        return _base.underestimatedCount
    }
    public __consuming func _copyContents(
        initializing buf: UnsafeMutableBufferPointer<Element>
    ) -> (Iterator, UnsafeMutableBufferPointer<Element>.Index) {
        return _base._copyContents(initializing: buf)
    }
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        return _base._customContainsEquatableElement(element)
    }
    public __consuming func _copyToContiguousArray() -> ContiguousArray<Element> {
        return _base._copyToContiguousArray()
    }
}

// LazySequence 实现 LazySequenceProtocol
extension LazySequence: LazySequenceProtocol {
    public typealias Elements = Base
    public var elements: Elements { return _base }
}


extension Sequence {
    public var lazy: LazySequence<Self> {
        return LazySequence(_base: self)
    }
}
