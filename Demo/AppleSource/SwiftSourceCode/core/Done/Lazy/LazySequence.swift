
/*
 LazySequenceProtocol 仅仅是提供了一个功能, elements.
 它主要是作为一个类型的标识符来进行使用. 所有的 lazy. map, filter, 都是添加到了这个 protocol 里面.
 */
public protocol LazySequenceProtocol: Sequence {
  associatedtype Elements: Sequence = Self where Elements.Element == Element
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

/*
 struct LazySequence 仅仅是一个代理, 将 base 进行存储.
 然后所有的 sequence 所有的能力, 代理给 base
 */
@frozen // lazy-performance
public struct LazySequence<Base: Sequence> {
  @usableFromInline
  internal var _base: Base
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
  @inlinable // lazy-performance
  public var elements: Elements { return _base }
}

/*
 Sequence 调用 lazy, 就是创建一个 LazySequence 来, 把自己传递过去.
 */
extension Sequence {
    @inlinable // protocol-only
    public var lazy: LazySequence<Self> {
        return LazySequence(_base: self)
  }
}


/*
 需要想清楚的是, map, filter, 这些函数在 Sequence 中调用的时候, 是真的去进行了迭代.
 但是在 lazy 上进行调用的时候, 是生成了一个对象, 这个对象, 会把 map, filter 的逻辑存起来, 把闭包存起来.
 同时, 这个对象, 又是 sequence 类型的. 所以, 它可以被迭代.
 等到它被迭代的时候, 才会真的去取值, 去用闭包改变值.
 这个模式, 使用了装饰者模式的概念.
 
 如何添加一个 lazy 的功能.
 首先, 创建一个对应功能的 sequence, 例如 lazyMapSequence.
 然后, 建立对应的 iterator, lazyMapSequence
 最后, 建立一个对应的函数, map, 在这个函数里面, 主要工作就是创建一个 lazyMapSequence 然后返回.
 */
