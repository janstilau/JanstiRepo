/*
 对于, LazyMapSequence 找个结构体来说, 他做的事情, 就是存储 base sequence 以及 transform 闭包.
 */
@frozen
public struct LazyMapSequence<Base: Sequence, Element> {
  public typealias Elements = LazyMapSequence
  @usableFromInline
  internal var _base: Base
  @usableFromInline
  internal let _transform: (Base.Element) -> Element
  @inlinable
  internal init(_base: Base, transform: @escaping (Base.Element) -> Element) {
    self._base = _base
    self._transform = transform
  }
}

/*
 一定要记住, Sequence 并不提供迭代的过程. 迭代的过程是交给 iterator 进行的.
 LazyMapSequence::Iterator 的定义区块, 真正的对于 iteratorProtocol 的定义, 在另外一个区块.
 */
extension LazyMapSequence {
  @frozen
  public struct Iterator {
    @usableFromInline
    internal var _base: Base.Iterator
    @usableFromInline
    internal let _transform: (Base.Element) -> Element

    @inlinable
    public var base: Base.Iterator { return _base }

    @inlinable
    internal init(
      _base: Base.Iterator, 
      _transform: @escaping (Base.Element) -> Element
    ) {
      self._base = _base
      self._transform = _transform
    }
  }
}

/*
 Map 的 iterator, 迭代的过程. 首先交给自己的 bese Iterator, 获取数据.
 然后在数据的基础上, 执行存储的 transform 闭包过程.
 bese Iterator 的实际类型是未知的. 他很有可能就是一个 lazySequence Iterator.
 */
extension LazyMapSequence.Iterator: IteratorProtocol, Sequence {
  @inlinable
  public mutating func next() -> Element? {
    /*
     _base.next 是一个 Optional, 这里的 map, 是 Optional 的 map.
     */
    return _base.next().map(_transform)
  }
}

/*
 在 lazySequence 里面, 所有的操作, 都是转交给了 base sequence 里面, 包括 makeIterator.
 而在 LazyMapSequence 这种, 实际自定义了操作了的 LazySequence 里面, 要按照需要, 复写某些方法, 比如, makeIterator.
 */
extension LazyMapSequence: LazySequenceProtocol {
  @inlinable
  public __consuming func makeIterator() -> Iterator {
    return Iterator(_base: _base.makeIterator(), _transform: _transform)
  }
  @inlinable
  public var underestimatedCount: Int {
    return _base.underestimatedCount
  }
}

/*
 和 C++ 一样, 特定的数据结构, 完成操作, 但是给外界使用的时候, 应该提供一个简便的方法.
 Map 方法, 是建立在 LazySequenceProtocol 协议上的, 这也是为什么要进行 lazy() 调用的原因.
 普通的 Sequence, 调用 lazy 成为了 LazySequenceProtocol 的实现类, 才能够调用 lazy, 变为一个 LazyMapSequence.
 而这个 LazyMapSequence, 还能够再次组装, 成为下一个 LazySequence 里面的 baseSequence.
 */
extension LazySequenceProtocol {
  @inlinable  public func map<U>(
    _ transform: @escaping (Element) -> U
  ) -> LazyMapSequence<Elements, U> {
    return LazyMapSequence(_base: elements, transform: transform)
  }
}

extension LazyMapSequence {
  @inlinable
  @available(swift, introduced: 5)
  public func map<ElementOfResult>(
    _ transform: @escaping (Element) -> ElementOfResult
  ) -> LazyMapSequence<Base, ElementOfResult> {
    return LazyMapSequence<Base, ElementOfResult>(
      _base: _base,
      transform: { transform(self._transform($0)) })
  }
}

public typealias LazyMapCollection<T: Collection,U> = LazyMapSequence<T,U>

extension LazyMapCollection: Collection {
  public typealias Index = Base.Index
  public typealias Indices = Base.Indices
  public typealias SubSequence = LazyMapCollection<Base.SubSequence, Element>

  @inlinable
  public var startIndex: Base.Index { return _base.startIndex }
  @inlinable
  public var endIndex: Base.Index { return _base.endIndex }

  @inlinable
  public func index(after i: Index) -> Index { return _base.index(after: i) }
  @inlinable
  public func formIndex(after i: inout Index) { _base.formIndex(after: &i) }

  /// Accesses the element at `position`.
  ///
  /// - Precondition: `position` is a valid position in `self` and
  ///   `position != endIndex`.
  @inlinable
  public subscript(position: Base.Index) -> Element {
    return _transform(_base[position])
  }

  @inlinable
  public subscript(bounds: Range<Base.Index>) -> SubSequence {
    return SubSequence(_base: _base[bounds], transform: _transform)
  }

  @inlinable
  public var indices: Indices {
    return _base.indices
  }

  /// A Boolean value indicating whether the collection is empty.
  @inlinable
  public var isEmpty: Bool { return _base.isEmpty }

  /// The number of elements in the collection.
  ///
  /// To check whether the collection is empty, use its `isEmpty` property
  /// instead of comparing `count` to zero. Unless the collection guarantees
  /// random-access performance, calculating `count` can be an O(*n*)
  /// operation.
  ///
  /// - Complexity: O(1) if `Index` conforms to `RandomAccessIndex`; O(*n*)
  ///   otherwise.
  @inlinable
  public var count: Int {
    return _base.count
  }

  @inlinable
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    return _base.index(i, offsetBy: n)
  }

  @inlinable
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    return _base.index(i, offsetBy: n, limitedBy: limit)
  }

  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return _base.distance(from: start, to: end)
  }
}

extension LazyMapCollection: BidirectionalCollection
  where Base: BidirectionalCollection {

  /// A value less than or equal to the number of elements in the collection.
  ///
  /// - Complexity: O(1) if the collection conforms to
  ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
  ///   of the collection.
  @inlinable
  public func index(before i: Index) -> Index { return _base.index(before: i) }

  @inlinable
  public func formIndex(before i: inout Index) {
    _base.formIndex(before: &i)
  }
}

extension LazyMapCollection: LazyCollectionProtocol { }

extension LazyMapCollection: RandomAccessCollection
  where Base: RandomAccessCollection { }

//===--- Support for s.lazy -----------------------------------------------===//

extension LazyMapCollection {
  @inlinable
  @available(swift, introduced: 5)
  public func map<ElementOfResult>(
    _ transform: @escaping (Element) -> ElementOfResult
  ) -> LazyMapCollection<Base, ElementOfResult> {
    return LazyMapCollection<Base, ElementOfResult>(
      _base: _base,
      transform: {transform(self._transform($0))})
  }
}
