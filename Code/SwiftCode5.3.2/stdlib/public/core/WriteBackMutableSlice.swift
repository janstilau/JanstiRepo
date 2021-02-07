// 专门, 为了这个函数, 创建了一个文件进行存储
internal func _writeBackMutableSlice<C, Slice_>(
    _ self_: inout C, bounds: Range<C.Index>, slice: Slice_
) where
    C: MutableCollection,
    Slice_: Collection,
    C.Element == Slice_.Element,
    C.Index == Slice_.Index {
    
    self_._failEarlyRangeCheck(bounds, bounds: self_.startIndex..<self_.endIndex)
    
    // FIXME(performance): can we use
    // _withUnsafeMutableBufferPointerIfSupported?  Would that create inout
    // aliasing violations if the newValue points to the same buffer?
    
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
    
    _precondition(
        selfElementIndex == selfElementsEndIndex,
        "Cannot replace a slice of a MutableCollection with a slice of a smaller size")
    _precondition(
        newElementIndex == newElementsEndIndex,
        "Cannot replace a slice of a MutableCollection with a slice of a larger size")
}

