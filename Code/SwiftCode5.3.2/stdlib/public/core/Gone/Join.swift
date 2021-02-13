// 在类的定义阶段, 仅仅是把相应的值, 存起来而已.
public struct JoinedSequence<Base: Sequence> where Base.Element: Sequence {
    public typealias Element = Base.Element.Element
    internal var _base: Base
    internal var _separator: ContiguousArray<Element>
    
    public init<Separator: Sequence>(base: Base, separator: Separator)
    where Separator.Element == Element {
        self._base = base
        self._separator = ContiguousArray(separator)
    }
}

extension JoinedSequence {
    public struct Iterator {
        internal var _base: Base.Iterator // base Sequence 的 iter.
        internal var _inner: Base.Element.Iterator? // 每个 Ele 是一个 Sequence, Ele 的 iter
        internal var _separatorData: ContiguousArray<Element>
        internal var _separator: ContiguousArray<Element>.Iterator?
        
        internal enum _JoinIteratorState {
            case start
            case generatingElements
            case generatingSeparator
            case end
        }
        internal var _state: _JoinIteratorState = .start
        public init<Separator: Sequence>(base: Base.Iterator, separator: Separator)
        where Separator.Element == Element {
            self._base = base
            self._separatorData = ContiguousArray(separator)
        }
    }
}

extension JoinedSequence.Iterator: IteratorProtocol {
    public typealias Element = Base.Element.Element
    // 根据 state 进行后续的处理.
    public mutating func next() -> Element? {
        while true {
            switch _state {
            case .start:
                if let nextSubSequence = _base.next() {
                    _inner = nextSubSequence.makeIterator()
                    _state = .generatingElements
                } else {
                    _state = .end
                    return nil
                }
                
            case .generatingElements:
                let result = _inner!.next()
                if _fastPath(result != nil) {
                    return result
                }
                _inner = _base.next()?.makeIterator()
                if _inner == nil {
                    _state = .end
                    return nil
                }
                if !_separatorData.isEmpty {
                    _separator = _separatorData.makeIterator()
                    _state = .generatingSeparator
                }
                
            case .generatingSeparator:
                let result = _separator!.next()
                if _fastPath(result != nil) {
                    return result
                }
                _state = .generatingElements
                
            case .end:
                return nil
            }
        }
    }
}

extension JoinedSequence: Sequence {
    public __consuming func makeIterator() -> Iterator {
        return Iterator(base: _base.makeIterator(), separator: _separator)
    }
    
    public __consuming func _copyToContiguousArray() -> ContiguousArray<Element> {
        var result = ContiguousArray<Element>()
        let separatorSize = _separator.count
        
        if separatorSize == 0 {
            for x in _base {
                result.append(contentsOf: x)
            }
            return result
        }
        
        var iter = _base.makeIterator()
        if let first = iter.next() {
            result.append(contentsOf: first)
            while let next = iter.next() {
                result.append(contentsOf: _separator)
                result.append(contentsOf: next)
            }
        }
        
        return result
    }
}

// JoinedSequence 实际的类型, 是不会暴露出去的. 暴露出去的, 仅仅是一个外层的函数而已.
// 这里, Sequence 里面的 element 也必须是 Sequence 才可以.
extension Sequence where Element: Sequence {
    public func joined<Separator: Sequence>(
        separator: Separator
    ) -> JoinedSequence<Self>
    where Separator.Element == Element.Element {
        return JoinedSequence(base: self, separator: separator)
    }
}
