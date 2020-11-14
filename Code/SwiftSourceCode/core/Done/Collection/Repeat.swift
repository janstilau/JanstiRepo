/*
 真正的存储的就两个值.
 */
public struct Repeated<Element> {
    public let count: Int
    public let repeatedValue: Element
}

/*
 提供对于 Collection 的适配.
 所有的这些, 都在模拟这是一个 Collection, 虽然我们知道, 他仅仅占用两个存储空间.
 这也表明了, Collection 仅仅是一个抽象概念, 和实际的内存大小无关.
 */
extension Repeated: RandomAccessCollection {
    public typealias Indices = Range<Int>
    public typealias Index = Int
    
    @inlinable // trivial-implementation
    internal init(_repeating repeatedValue: Element, count: Int) {
        self.count = count
        self.repeatedValue = repeatedValue
    }
    
    /*
     这本来就是一个抽象的概念, 所以从 0 开始, 是固定的.
     */
    @inlinable // trivial-implementation
    public var startIndex: Index {
        return 0
    }
    
    @inlinable // trivial-implementation
    public var endIndex: Index {
        return count
    }
    
    /*
     所有的这些 index, 都返回同样的值.
     */
    @inlinable // trivial-implementation
    public subscript(position: Int) -> Element {
        return repeatedValue
    }
}

/*
 这是一个函数, 隐藏了创建的实际的类型.
 */
@inlinable // trivial-implementation
public func repeatElement<T>(_ element: T, count n: Int) -> Repeated<T> {
    return Repeated(_repeating: element, count: n)
}
