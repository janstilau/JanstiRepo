/*
 当, 想要表达一个集合的时候, 但又只有一个数据, 那么这个类就可以使用了.
 */
@frozen // trivial-implementation
public struct CollectionOfOne<Element> {
  @usableFromInline // trivial-implementation
  internal var _element: Element // 首先, 自然还是要把 ele 存储一下.
  @inlinable // trivial-implementation
  public init(_ element: Element) {
    self._element = element
  }
}

extension CollectionOfOne {
  @frozen // trivial-implementation
  public struct Iterator {
    @usableFromInline // trivial-implementation
    internal var _elements: Element?
    @inlinable // trivial-implementation
    public // @testable
    init(_elements: Element?) {
      self._elements = _elements
    }
  }
}

/*
 这里就是关键, 只进行一次取值, 然后 next 就是 nil 了.
 这里, 是 CollecitonOfOne 对于 Sequence 的适配.
 */
extension CollectionOfOne.Iterator: IteratorProtocol {
  @inlinable // trivial-implementation
  public mutating func next() -> Element? {
    let result = _elements
    _elements = nil
    return result
  }
}

extension CollectionOfOne: RandomAccessCollection, MutableCollection {

  public typealias Index = Int
  public typealias Indices = Range<Int>
  public typealias SubSequence = Slice<CollectionOfOne<Element>>

  @inlinable // trivial-implementation
  public var startIndex: Index {
    return 0
  }

  @inlinable // trivial-implementation
  public var endIndex: Index {
    return 1
  }
  
  @inlinable // trivial-implementation
  public func index(after i: Index) -> Index {
    _precondition(i == startIndex)
    return 1
  }

  @inlinable // trivial-implementation
  public func index(before i: Index) -> Index {
    _precondition(i == endIndex)
    return 0
  }

  @inlinable // trivial-implementation
  public __consuming func makeIterator() -> Iterator {
    return Iterator(_elements: _element)
  }

  /// Accesses the element at the specified position.
  ///
  /// - Parameter position: The position of the element to access. The only
  ///   valid position in a `CollectionOfOne` instance is `0`.
  @inlinable // trivial-implementation
  public subscript(position: Int) -> Element {
    _read {
      _precondition(position == 0, "Index out of range")
      yield _element
    }
    _modify {
      _precondition(position == 0, "Index out of range")
      yield &_element
    }
  }

  @inlinable // trivial-implementation
  public subscript(bounds: Range<Int>) -> SubSequence {
    get {
      _failEarlyRangeCheck(bounds, bounds: 0..<1)
      return Slice(base: self, bounds: bounds)
    }
    set {
      _failEarlyRangeCheck(bounds, bounds: 0..<1)
      let n = newValue.count
      _precondition(bounds.count == n, "CollectionOfOne can't be resized")
      if n == 1 { self = newValue.base }
    }
  }

  @inlinable // trivial-implementation
  public var count: Int {
    return 1
  }
}

extension CollectionOfOne: CustomDebugStringConvertible {
  /// A textual representation of the collection, suitable for debugging.
  public var debugDescription: String {
    return "CollectionOfOne(\(String(reflecting: _element)))"
  }
}

extension CollectionOfOne: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(self, children: ["element": _element])
  }
}
