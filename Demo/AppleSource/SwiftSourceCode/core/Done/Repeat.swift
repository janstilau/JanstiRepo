@frozen
public struct Repeated<Element> {
    /*
     真正的存储的就两个值.
     */
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
    
    /// Creates an instance that contains `count` elements having the
    /// value `repeatedValue`.
    @inlinable // trivial-implementation
    internal init(_repeating repeatedValue: Element, count: Int) {
        _precondition(count >= 0, "Repetition count should be non-negative")
        self.count = count
        self.repeatedValue = repeatedValue
    }
    
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
        // 这里, 还是做了必要的 range 的判断.
        _precondition(position >= 0 && position < count, "Index out of range")
        return repeatedValue
    }
}

/*
 这是一个函数, 隐藏了创建的实际的类型.
 当然, 这个函数的内部, 生产出Repeated这个结构体来, 是暴露出去了.
 不过, 一般的这种函数, 返回的是一个接口对象, 而不是实际对象.
 为什么需要一个Repeated结构体. 因为里面的都是重复数据啊, 没有必要存储这么多重复数据, 存储数据, 以及次数就可以.
 
 泛型函数里面, 提供了类型信息, 生成对应的泛型结构.
 */
@inlinable // trivial-implementation
public func repeatElement<T>(_ element: T, count n: Int) -> Repeated<T> {
    return Repeated(_repeating: element, count: n)
}
