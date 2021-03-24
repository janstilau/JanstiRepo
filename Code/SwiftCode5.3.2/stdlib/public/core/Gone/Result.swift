// 相比, Optinal 只会在 Some 里面有关联值, 这里, 会在两种情况下都有关联值. 在 Failure 里面, 关联一个 Error.
public enum Result<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    
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
    
    // 最后还是返回一个 success
    // 不过, 传过来的 closure 是把 success 输入, 最终输出成为一个 Result
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
    
    // FlatMap. 将构建 Result 的过程, 变为了闭包进行传递.
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
    
    // 从这里看, 这个 Result 类型, 会和 catch 大大的配合使用.
    public func get() throws -> Success {
        switch self {
        case let .success(success):
            return success
        case let .failure(failure):
            throw failure
        }
    }
}

// 这里, init 的时候, 会调用一段会 throw exception 的 block, 成功, 返回 success(值), 不成功, 会捕捉到异常.
// 用这种办法, 可以大大的减少 try catch 的使用.
extension Result where Failure == Swift.Error {
    public init(catching body: () throws -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(error)
        }
    }
}

extension Result: Equatable where Success: Equatable, Failure: Equatable { }

extension Result: Hashable where Success: Hashable, Failure: Hashable { }

/*
 When writing a function, method, or other API that might fail, you use the throws keyword on the declaration to indicate that the API call can throw an error.
 However, you can’t use the throws keyword to model APIs that return asynchronously. Instead, use the Result enumeration to capture information about whether an asychronous call succeeds or fails, and use the associated values for the Result.success(_:) and Result.failure(_:) cases to carry information about the result of the call.
 
 let queue = DispatchQueue(label: "com.example.queue")

 enum EntropyError: Error {
     case entropyDepleted
 }

 struct AsyncRandomGenerator {
     static let entropyLimit = 5
     var count = 0
     
     mutating func fetchRemoteRandomNumber(
         completion: @escaping (Result<Int, EntropyError>) -> Void) {
         let result: Result<Int, EntropyError>
         if count < AsyncRandomGenerator.entropyLimit {
             result = .success(Int.random(in: 1...100))
         } else {
             // Supply a failure reason when the caller hits the limit.
             result = .failure(.entropyDepleted)
         }
         count += 1
         queue.asyncAfter(deadline: .now() + 2) {
             completion(result)
         }
     }
 }

 这个类, 其实就是 success, model, error 的封装.
 
 Call the initializer that wraps a throwing expression when you need to serialize or memoize the result.
 
 */
