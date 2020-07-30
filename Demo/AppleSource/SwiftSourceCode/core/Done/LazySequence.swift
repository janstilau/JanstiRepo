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
/// Lazy, 将操作, 和原始数据存储了起来.
/// Sequence operations taking closure arguments, such as `map` and
/// `filter`, are normally eager: they use the closure immediately and
/// return a new array.  Using the `lazy` property gives the standard
/// library explicit permission to store the closure and the sequence
/// in the result, and defer computation until it is needed.
///
///
/// 以下说的是, lazy 怎么扩展功能. 以 scan 功能为例子.
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
///       目前这样写, scan 就是非 lazy 的.
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
///
///     Iterator 是真正返回数据的地方. 所以, 需要存储原始的 iterator, 作为原始数据的获取方式, 需要存储闭包, 作为原始数据的处理过程.
///     Sequence 将闭包和原始的 Iterator 传入, Sequence 里面的数据不会轻易改变, 改变的仅仅是 iterator, 在迭代的过程中, 不断的进行数据的改变
///     struct LazyScanIterator<Base: IteratorProtocol, ResultElement>
///       : IteratorProtocol {
///       // 在迭代的过程中, 提前算出下一个数据的值.
///       mutating func next() -> ResultElement? {
///         return nextElement.map { result in
///           nextElement = base.next().map { nextPartialResult(result, $0) }
///           return result
///         }
///       }
///       var nextElement: ResultElement? // The next result of next().
///       var base: Base                  // The underlying iterator.
///       let nextPartialResult: (ResultElement, Base.Element) -> ResultElement
///     }
///
///     // Sequence 记录下 init 值, base Sequence 的值, 以及闭包值. 然后每次迭代的时候, 将这些生成一个新的 iterator.
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
/// // 然后, 在 LazySequenceProtocol 中定义 scan 方法, 在这个方法内部, 是将 Sequence 本身传递到 LazyScanSequence 中去.
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
/// - See also: `LazySequenceProtocol`
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
 通过 lazy 函数, 简历了一个适配器. 在该适配器里面, 存储了原有的 sequence, 所有的操作, 都代理给了原有的 sequence 函数. 这样, 对于 lazySequence 的任何操作, 其实就是操作 原有的 sequence.
 如果想要完成某个 lazy 操作, 比如例子中的 scan, 就要自定义 LazyScanSequence, 定义 LazyScanSequenceIterator .
 在其中, Sequence -> LazySequence -> LazyScanSequence, 他们都是 Sequence.
 LazyScanSequenceIterator 会取 base, 也就是 LazySequence 的数据, LazySequence 转过来又去取 Sequence 的数据, 然后 LazyScanSequenceIterator 中, 会运用传递过来的闭包, 对数据进行操作.
 LazyScanSequence 本身也是一个 LazySequence, 所以可以在它后面在进行 map 操作. 在 LazyMapSequence 中, 取值就会进行上面的操作.
 所以, lazy 函数, 本身就是一个创建适配器的过程. 这个适配器, 是 lazySequence 的.
 在 LazySequenceProtocol 中定义的各个方法, 都不是免费的. 都要定义相关的 Sequence, 进行各个方法的包装.
 
 这是一个装饰者模式的典型例子.
 各个方法, 作为简便的方法, 生成了一个新的 LazySequenceProtocol 的实例类. 在生成过程中, 将自己传入. 作为 base 存储到新的实例对象中.
 在最后取值的过程中, 先从实例对象取值, 然后自己操作, 但是自己本身也会被当做 base 存储.
 最后, 生成的数据的过程, 就是链式的不断调用 block 的过程.
 */
