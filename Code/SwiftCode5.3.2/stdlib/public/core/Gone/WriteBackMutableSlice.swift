// 专门, 为了这个函数, 创建了一个文件进行存储
// self_, Slice_ 的命名方式, 是遵循什么规律吗 ????

// 这里感觉定义的不好, C: MutableCollection, Slice_: Collection 更加的友好一点.
// 这里, 传递 Inout 过来, 应该就不会有写时复制了.
// 专门一个函数, 处理 MutableCollection 的替换工作, 感觉可以写到 MutableCollection 的内部.
internal func _writeBackMutableSlice<C, Slice_>(
    _ self_: inout C,
    bounds: Range<C.Index>,
    slice: Slice_
) where
    C: MutableCollection,
    Slice_: Collection,
    C.Element == Slice_.Element,
    C.Index == Slice_.Index {
    
    var selfElementIndex = bounds.lowerBound
    let selfElementsEndIndex = bounds.upperBound
    var newElementIndex = slice.startIndex
    let newElementsEndIndex = slice.endIndex
    
    while selfElementIndex != selfElementsEndIndex &&
            newElementIndex != newElementsEndIndex {
        
        self_[selfElementIndex] = slice[newElementIndex]
        self_.formIndex(after: &selfElementIndex)
        slice.formIndex(after: &newElementIndex)
    }
}

