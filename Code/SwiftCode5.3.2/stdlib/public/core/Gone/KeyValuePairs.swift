
// 这个类, 不太实用. 直接使用 Array[(Key, Value)] 不更好吗
// 唯一的好处在于, 可以使用字典的形式进行初始化而已.
public struct KeyValuePairs<Key, Value>: ExpressibleByDictionaryLiteral {
    internal let _elements: [(Key, Value)]
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self._elements = elements
    }
}

extension KeyValuePairs: RandomAccessCollection {
    public typealias Element = (key: Key, value: Value)
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<KeyValuePairs>
    public var startIndex: Index { return 0 }
    public var endIndex: Index { return _elements.endIndex }
    public subscript(position: Index) -> Element {
        return _elements[position]
    }
}

