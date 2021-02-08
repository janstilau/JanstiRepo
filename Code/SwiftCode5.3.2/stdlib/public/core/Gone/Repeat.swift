// 这个类, 一般不会用到, 它主要是系统 Api, 为了将重复这个概念, 包装成为 Collection 所使用的一个类.
// 这个类, 主要还是 Collection 的配套使用.
public struct Repeated<Element> {
    public let count: Int
    public let repeatedValue: Element
}

extension Repeated: RandomAccessCollection {
    public typealias Indices = Range<Int>
    public typealias Index = Int
    
    internal init(_repeating repeatedValue: Element, count: Int) {
        self.count = count
        self.repeatedValue = repeatedValue
    }
    public var startIndex: Index {
        return 0
    }
    public var endIndex: Index {
        return count
    }
    // 所有的下标操作, 都是返回同样的值
    // Bidirection 是由于 Index 是 Int 自动完成的.
    public subscript(position: Int) -> Element {
        return repeatedValue
    }
}

// 使用一个简便的函数, 返回一个实际的类型, 在这个函数内部, 根据函数的自动类型推到, 识别出泛型类型来. 这种手法很常见.
// 在使用返回值的时候, 并不是使用实际的类型的接口, 而是使用实际类型所属的协议的接口. 这是 Swift 更加抽象的一层.
public func repeatElement<T>(_ element: T, count n: Int) -> Repeated<T> {
    return Repeated(_repeating: element, count: n)
}
