/// Returns a sequence formed from `first` and repeated lazy applications of
/// `next`.
///
/// The first element in the sequence is always `first`, and each successive
/// element is the result of invoking `next` with the previous element. The
/// sequence ends when `next` returns `nil`. If `next` never returns `nil`, the
/// sequence is infinite.
///
/// This function can be used to replace many cases that were previously handled
/// using C-style `for` loops.
///
/// Example:
///
///     // Walk the elements of a tree from a node up to the root
///     for node in sequence(first: leaf, next: { $0.parent }) {
///       // node is leaf, then leaf.parent, then leaf.parent.parent, etc.
///     }
///
///     // Iterate over all powers of two (ignoring overflow)
///     for value in sequence(first: 1, next: { $0 * 2 }) {
///       // value is 1, then 2, then 4, then 8, etc.
///     }
///
/// - Parameter first: The first element to be returned from the sequence.
/// - Parameter next: A closure that accepts the previous sequence element and
///   returns the next element.
/// - Returns: A sequence that starts with `first` and continues with every
///   value returned by passing the previous element to `next`.
@inlinable // generic-performance
public func sequence<T>(first: T, next: @escaping (T) -> T?) -> UnfoldFirstSequence<T> {
    // The trivial implementation where the state is the next value to return
    // has the downside of being unnecessarily eager (it evaluates `next` one
    // step in advance). We solve this by using a boolean value to disambiguate
    // between the first value (that's computed in advance) and the rest.
    return sequence(state: (first, true), next: { (state: inout (T?, Bool)) -> T? in
        switch state {
        case (let value, true):
            state.1 = false
            return value
        case (let value?, _):
            let nextValue = next(value)
            state.0 = nextValue
            return nextValue
        case (nil, _):
            return nil
        }
    })
}

///
/// Example:
///
///     // Interleave two sequences that yield the same element type
///     sequence(state: (false, seq1.makeIterator(), seq2.makeIterator()), next: { iters in
///       iters.0 = !iters.0 // 这里, iters 的修改, 会影响到实际的存储的值.
///       return iters.0 ? iters.1.next() : iters.2.next()
///     })
///
/// - Parameter state: The initial state that will be passed to the closure.
/// - Parameter next: A closure that accepts an `inout` state and returns the
///   next element of the sequence.
/// - Returns: A sequence that yields each successive value from `next`.
@inlinable // generic-performance
public func sequence<T, State>(state: State, next: @escaping (inout State) -> T?)
-> UnfoldSequence<T, State> {
    return UnfoldSequence(_state: state, _next: next)
}

// UnfoldFirstSequence 仅仅是一层包装而已.
public typealias UnfoldFirstSequence<T> = UnfoldSequence<T, (T?, Bool)>

// 一个特殊的数据结果, 就是为了 sequence<T, State> 函数使用的.
// 当一个新的概念出现的时候, 一定是, 要设计一个特殊的数据结构来配合相关的算法来实现. 但是, 这个数据结构, 最好不要暴露出去.
// 暴露给外界的, 应该是一个简单的接口.
public struct UnfoldSequence<Element, State>: Sequence, IteratorProtocol {
    
    @inlinable // generic-performance
    public mutating func next() -> Element? {
        guard !_done else { return nil }
        // 因为, next 里面的 state 是 inout 的, 所以每一次调用, 都会修改 _state 的数据.
        if let elt = _next(&_state) {
            return elt
        } else {
            _done = true
            return nil
        }
    }
    
    // 从这里的命名来看, 这是一个内部类, 不应该直接暴露给外界使用.
    // 首先, 需要存一下起始数据, 还要存一下, 根据现有数据进行抽取的过程. 这里, 存储的数据, 和迭代的数据不一定相同, 可以通过闭包进行配置.
    internal init(_state: State, _next: @escaping (inout State) -> Element?) {
        self._state = _state
        self._next = _next
    }
    
    internal var _state: State
    internal let _next: (inout State) -> Element?
    internal var _done = false
}
