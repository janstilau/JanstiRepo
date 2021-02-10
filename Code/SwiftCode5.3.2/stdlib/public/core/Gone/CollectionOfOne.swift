// 这个类, 用在了 Insert 方法里面, insert, 就是 replaceSubrange(i..<i, with: CollectionOfOne(newElement)), 所以, 其实还是为了适配 replaceSubrange 这个 primitive Method 的要求.
// 因为, 这个类就是表示的是一个值, 所以, 它的数据就是这样一个值.
public struct CollectionOfOne<Element> {
    internal var _element: Element
    public init(_ element: Element) {
        self._element = element
    }
}

extension CollectionOfOne {
    public struct Iterator {
        internal var _elements: Element? // 这里还是感觉命名 Element 的好. 因为这个类就是单一数据, 最好体现出来.
        public init(_elements: Element?) {
            self._elements = _elements
        }
    }
}

// 对于 Sequence 的适配.
extension CollectionOfOne.Iterator: IteratorProtocol {
    public mutating func next() -> Element? {
        let result = _elements
        _elements = nil
        return result
    }
}

// 对于 Collection 的适配.
extension CollectionOfOne: RandomAccessCollection, MutableCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<CollectionOfOne<Element>>
    public var startIndex: Index {
        return 0
    }
    public var endIndex: Index {
        return 1
    }
    public func index(after i: Index) -> Index {
        return 1
    }
    public func index(before i: Index) -> Index {
        return 0
    }
    public __consuming func makeIterator() -> Iterator {
        return Iterator(_elements: _element)
    }
    public subscript(position: Int) -> Element {
        _read {
            _precondition(position == 0, "Index out of range")
            yield _element
        }
        _modify {
            _precondition(position == 0, "Index out of range")
            yield &_element // ??? yield
        }
    }
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
    public var count: Int {
        return 1
    }
}

extension CollectionOfOne: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(self, children: ["element": _element])
    }
}
