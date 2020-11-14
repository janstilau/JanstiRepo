public protocol LazyCollectionProtocol: Collection, LazySequenceProtocol 
where Elements: Collection {
    
}

extension LazyCollectionProtocol {		
   @inlinable // protocol-only
   public var lazy: LazyCollection<Elements> {		
     return elements.lazy		
   }		
 }		
		
 extension LazyCollectionProtocol where Elements: LazyCollectionProtocol {		
   @inlinable // protocol-only
   public var lazy: Elements {		
     return elements		
   }		
 }

/// A collection containing the same elements as a `Base` collection,
/// but on which some operations such as `map` and `filter` are
/// implemented lazily.
///
/// - See also: `LazySequenceProtocol`, `LazyCollection`
public typealias LazyCollection<T: Collection> = LazySequence<T>

extension LazyCollection: Collection {
  public typealias Index = Base.Index
  public typealias Indices = Base.Indices
  public typealias SubSequence = Slice<LazySequence>

  @inlinable
  public var startIndex: Index { return _base.startIndex }

  @inlinable
  public var endIndex: Index { return _base.endIndex }

  @inlinable
  public var indices: Indices { return _base.indices }

  @inlinable
  public func index(after i: Index) -> Index {
    return _base.index(after: i)
  }

  @inlinable
  public subscript(position: Index) -> Element {
    return _base[position]
  }

  @inlinable
  public var isEmpty: Bool {
    return _base.isEmpty
  }

  @inlinable
  public var count: Int {
    return _base.count
  }
    
  @inlinable
  public func _customIndexOfEquatableElement(
    _ element: Element
  ) -> Index?? {
    return _base._customIndexOfEquatableElement(element)
  }

  @inlinable
  public func _customLastIndexOfEquatableElement(
    _ element: Element
  ) -> Index?? {
    return _base._customLastIndexOfEquatableElement(element)
  }

  // TODO: swift-3-indexing-model - add docs
  @inlinable
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    return _base.index(i, offsetBy: n)
  }

  // TODO: swift-3-indexing-model - add docs
  @inlinable
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    return _base.index(i, offsetBy: n, limitedBy: limit)
  }

  // TODO: swift-3-indexing-model - add docs
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return _base.distance(from:start, to: end)
  }
}

extension LazyCollection: LazyCollectionProtocol { }

extension LazyCollection: BidirectionalCollection
  where Base: BidirectionalCollection {
  @inlinable
  public func index(before i: Index) -> Index {
    return _base.index(before: i)
  }
}

extension LazyCollection: RandomAccessCollection
  where Base: RandomAccessCollection {}

extension Slice: LazySequenceProtocol where Base: LazySequenceProtocol { }
extension ReversedCollection: LazySequenceProtocol where Base: LazySequenceProtocol { }
