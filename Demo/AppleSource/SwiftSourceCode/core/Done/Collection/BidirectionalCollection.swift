/*
 和 Colleciton 相比, 没有太大的区别, 仅仅是提供了向前遍历的方式.
 */

public protocol BidirectionalCollection: Collection
where SubSequence: BidirectionalCollection, Indices: BidirectionalCollection {
  // FIXME: Only needed for associated type inference.
  override associatedtype Element
  override associatedtype Index
  override associatedtype SubSequence
  override associatedtype Indices

  func index(before i: Index) -> Index
  func formIndex(before i: inout Index)

  override func index(after i: Index) -> Index
  override func formIndex(after i: inout Index)

  @_nonoverride func index(_ i: Index, offsetBy distance: Int) -> Index
  @_nonoverride func index(
    _ i: Index, offsetBy distance: Int, limitedBy limit: Index
  ) -> Index?

  @_nonoverride func distance(from start: Index, to end: Index) -> Int
  override var indices: Indices { get }
  override subscript(bounds: Range<Index>) -> SubSequence { get }
  @_borrowed
  override subscript(position: Index) -> Element { get }
  override var startIndex: Index { get }
  override var endIndex: Index { get }
}

/// Default implementation for bidirectional collections.
extension BidirectionalCollection {

  @inlinable // protocol-only
  @inline(__always)
  public func formIndex(before i: inout Index) {
    i = index(before: i)
  }

  @inlinable // protocol-only
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return _index(i, offsetBy: distance)
  }

  @inlinable // protocol-only
  internal func _index(_ i: Index, offsetBy distance: Int) -> Index {
    if distance >= 0 {
      return _advanceForward(i, by: distance)
    }
    var i = i
    for _ in stride(from: 0, to: distance, by: -1) {
      formIndex(before: &i)
    }
    return i
  }

  @inlinable // protocol-only
  public func index(
    _ i: Index, offsetBy distance: Int, limitedBy limit: Index
  ) -> Index? {
    return _index(i, offsetBy: distance, limitedBy: limit)
  }

  @inlinable // protocol-only
  internal func _index(
    _ i: Index, offsetBy distance: Int, limitedBy limit: Index
  ) -> Index? {
    if distance >= 0 {
      return _advanceForward(i, by: distance, limitedBy: limit)
    }
    var i = i
    for _ in stride(from: 0, to: distance, by: -1) {
      if i == limit {
        return nil
      }
      formIndex(before: &i)
    }
    return i
  }

  @inlinable // protocol-only
  public func distance(from start: Index, to end: Index) -> Int {
    return _distance(from: start, to: end)
  }

  @inlinable // protocol-only
  internal func _distance(from start: Index, to end: Index) -> Int {
    var start = start
    var count = 0

    if start < end {
      while start != end {
        count += 1
        formIndex(after: &start)
      }
    } else if start > end {
      while start != end {
        count -= 1
        formIndex(before: &start)
      }
    }

    return count
  }
}

extension BidirectionalCollection where SubSequence == Self {
  @inlinable // protocol-only
  public mutating func popLast() -> Element? {
    guard !isEmpty else { return nil }
    let element = last!
    self = self[startIndex..<index(before: endIndex)]
    return element
  }

  @inlinable // protocol-only
  @discardableResult
  public mutating func removeLast() -> Element {
    let element = last!
    self = self[startIndex..<index(before: endIndex)]
    return element
  }

  @inlinable // protocol-only
  public mutating func removeLast(_ k: Int) {
    if k == 0 { return }
    _precondition(k >= 0, "Number of elements to remove should be non-negative")
    _precondition(count >= k,
      "Can't remove more items from a collection than it contains")
    self = self[startIndex..<index(endIndex, offsetBy: -k)]
  }
}

extension BidirectionalCollection {
  @inlinable // protocol-only
  public __consuming func dropLast(_ k: Int) -> SubSequence {
    _precondition(
      k >= 0, "Can't drop a negative number of elements from a collection")
    let end = index(
      endIndex,
      offsetBy: -k,
      limitedBy: startIndex) ?? startIndex
    return self[startIndex..<end]
  }

  @inlinable // protocol-only
  public __consuming func suffix(_ maxLength: Int) -> SubSequence {
    _precondition(
      maxLength >= 0,
      "Can't take a suffix of negative length from a collection")
    let start = index(
      endIndex,
      offsetBy: -maxLength,
      limitedBy: startIndex) ?? startIndex
    return self[start..<endIndex]
  }
}

