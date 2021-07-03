
/*
    Subject 既可以当做 Publisher, 又可以当做是 Subsriber
 */
/// Represents an object that is both an observable sequence as well as an observer.
public protocol SubjectType : ObservableType {
    /// The type of the observer that represents this subject.
    ///
    /// Usually this type is type of subject itself, but it doesn't have to be.
    associatedtype Observer: ObserverType

    /// Returns observer interface for subject.
    ///
    /// - returns: Observer interface for subject.
    func asObserver() -> Observer
    
}
