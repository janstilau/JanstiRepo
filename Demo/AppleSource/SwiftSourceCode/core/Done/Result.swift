/*
 要么成功, 要么失败.
 每一种, 都有着关联对象.
 因为有些时候, 确实是两中情况都要关联数据. 不过, Result 的使用, 还是不如 Optional 的.
 */
@frozen
public enum Result<Success, Failure: Error> {
  case success(Success)
  case failure(Failure)
    
    /*
     如果, 当前值是 Success, 那就去除当前值来, 然后重新放到 success 中当做关联值.
     */
  public func map<NewSuccess>(
    _ transform: (Success) -> NewSuccess
  ) -> Result<NewSuccess, Failure> {
    switch self {
    case let .success(success):
      return .success(transform(success))
    case let .failure(failure):
      return .failure(failure)
    }
  }
  
    /*
     和 map 刚好相反.
     可以看到, 命名上, 还是优先处理正数据.
     */
  public func mapError<NewFailure>(
    _ transform: (Failure) -> NewFailure
  ) -> Result<Success, NewFailure> {
    switch self {
    case let .success(success):
      return .success(success)
    case let .failure(failure):
      return .failure(transform(failure))
    }
  }
  
    /*
    和 Optional 的一样, flatMap 中传入的闭包, 是直接将关联值, 变为一个 Result 类型.
     */
  public func flatMap<NewSuccess>(
    _ transform: (Success) -> Result<NewSuccess, Failure>
  ) -> Result<NewSuccess, Failure> {
    switch self {
    case let .success(success):
      return transform(success)
    case let .failure(failure):
      return .failure(failure)
    }
  }
  
  public func flatMapError<NewFailure>(
    _ transform: (Failure) -> Result<Success, NewFailure>
  ) -> Result<Success, NewFailure> {
    switch self {
    case let .success(success):
      return .success(success)
    case let .failure(failure):
      return transform(failure)
    }
  }
  
  public func get() throws -> Success {
    switch self {
    case let .success(success):
      return success
    case let .failure(failure):
      throw failure
    }
  }
}

extension Result where Failure == Swift.Error {
  @_transparent
  public init(catching body: () throws -> Success) {
    do {
      self = .success(try body())
    } catch {
      self = .failure(error)
    }
  }
}

/*
 如果关联值, 都符合 Equatable, 那么判等会被很简单的. 首先自然是枚举值的判断, 在枚举值相同的情况下, 就是各个关联值的判断了.
 */
extension Result: Equatable where Success: Equatable, Failure: Equatable { }
extension Result: Hashable where Success: Hashable, Failure: Hashable { }
