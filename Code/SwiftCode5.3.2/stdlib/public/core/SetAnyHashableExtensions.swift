
extension Set where Element == AnyHashable {
    @inlinable
    public mutating func insert<ConcreteElement: Hashable>(
        _ newMember: __owned ConcreteElement
    ) -> (inserted: Bool, memberAfterInsert: ConcreteElement) {
        let (inserted, memberAfterInsert) =
            insert(AnyHashable(newMember))
        return (
            inserted: inserted,
            memberAfterInsert: memberAfterInsert.base as! ConcreteElement)
    }
    
    @inlinable
    @discardableResult
    public mutating func update<ConcreteElement: Hashable>(
        with newMember: __owned ConcreteElement
    ) -> ConcreteElement? {
        return update(with: AnyHashable(newMember))
            .map { $0.base as! ConcreteElement }
    }
    
    @inlinable
    @discardableResult
    public mutating func remove<ConcreteElement: Hashable>(
        _ member: ConcreteElement
    ) -> ConcreteElement? {
        return remove(AnyHashable(member))
            .map { $0.base as! ConcreteElement }
    }
}
