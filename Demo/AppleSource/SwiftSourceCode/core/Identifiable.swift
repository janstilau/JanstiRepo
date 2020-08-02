/// A class of types whose instances hold the value of an entity with stable identity.

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Identifiable {

  /// A type representing the stable identity of the entity associated with `self`.
  associatedtype ID: Hashable

  /// The stable identity of the entity associated with `self`.
  var id: ID { get }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Identifiable where Self: AnyObject {
  public var id: ObjectIdentifier {
    return ObjectIdentifier(self)
  }
}
