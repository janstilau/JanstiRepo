// 这是一个 mutating 方法, 所以只能用到 var 上面.
// 实现的原理, 就是前后对调. 不过, 这里使用的是 Collection, 所以是通用的行为, 而不单单是 array.
extension MutableCollection where Self: BidirectionalCollection {
    public mutating func reverse() {
        if isEmpty { return }
        var f = startIndex
        var l = index(before: endIndex)
        while f < l {
            swapAt(f, l)
            formIndex(after: &f)
            formIndex(before: &l)
        }
    }
}

/*
 在 C++ 里面, reverse Iterator 是包装的原来的 iterator, 然后所有的操作, 是原来的 iterator 的反操作.
 在这里, 所有的操作, 都是对于原来的 base 的包装. 思路和上面是一样的, 不过是两种语言抽象的位置不同.
 */
public struct ReversedCollection<Base: BidirectionalCollection> {
    public let _base: Base
    internal init(_base: Base) {
        self._base = _base
    }
}
extension ReversedCollection {
    public struct Iterator {
        internal let _base: Base
        internal var _position: Base.Index
        init(_base: Base) {
            self._base = _base
            // 初始化的时候, 记录的是 _base 的 end.
            self._position = _base.endIndex
        }
    }
}
extension ReversedCollection.Iterator: IteratorProtocol, Sequence {
    public typealias Element = Base.Element
    // 每次 Next 的时候, 是不断地使用 formIndex(before 去改变 _position 的值.
    public mutating func next() -> Element? {
        guard _fastPath(_position != _base.startIndex) else { return nil }
        _base.formIndex(before: &_position)
        return _base[_position]
    }
}
extension ReversedCollection: Sequence {
    public typealias Element = Base.Element
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_base: _base)
    }
}

extension ReversedCollection {
    public struct Index {
        public let base: Base.Index
        public init(_ base: Base.Index) {
            self.base = base
        }
    }
}

extension ReversedCollection.Index: Comparable {
    public static func == (
        lhs: ReversedCollection<Base>.Index,
        rhs: ReversedCollection<Base>.Index
    ) -> Bool {
        return lhs.base == rhs.base
    }
    public static func < (
        lhs: ReversedCollection<Base>.Index,
        rhs: ReversedCollection<Base>.Index
    ) -> Bool {
        return lhs.base > rhs.base
    }
}

extension ReversedCollection.Index: Hashable where Base.Index: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(base)
    }
}

extension ReversedCollection: BidirectionalCollection {  
    public var startIndex: Index {
        return Index(_base.endIndex)
    }
    public var endIndex: Index {
        return Index(_base.startIndex)
    }
    public func index(after i: Index) -> Index {
        return Index(_base.index(before: i.base))
    }
    public func index(before i: Index) -> Index {
        return Index(_base.index(after: i.base))
    }
    public func index(_ i: Index, offsetBy n: Int) -> Index {
        // FIXME: swift-3-indexing-model: `-n` can trap on Int.min.
        return Index(_base.index(i.base, offsetBy: -n))
    }
    public func index(
        _ i: Index, offsetBy n: Int, limitedBy limit: Index
    ) -> Index? {
        // FIXME: swift-3-indexing-model: `-n` can trap on Int.min.
        return _base.index(i.base, offsetBy: -n, limitedBy: limit.base)
            .map(Index.init)
    }
    public func distance(from start: Index, to end: Index) -> Int {
        return _base.distance(from: end.base, to: start.base)
    }
    public subscript(position: Index) -> Element {
        return _base[_base.index(before: position.base)]
    }
}

extension ReversedCollection: RandomAccessCollection where Base: RandomAccessCollection { }

extension ReversedCollection {
    public __consuming func reversed() -> Base {
        return _base
    }
}

extension BidirectionalCollection {
    public __consuming func reversed() -> ReversedCollection<Self> {
        return ReversedCollection(_base: self)
    }
}
