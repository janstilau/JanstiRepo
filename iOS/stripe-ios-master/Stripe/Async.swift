
class Future<Value> {
    
    typealias Result = Swift.Result<Value, Error>
    
    fileprivate var result: Result? {
        // 如果, Result 为 Success, 就触发 report 方法.
        // Map 本身是一个将 Result<Success, Error> -> 变为 Result<NewSuccess, Error> 的方法.
        // 这里, report 返回 Void, 就是 NewSuccess 就是 Void.
        didSet { result.map(report) }
    }
    private var callbacks = [(Result) -> Void]()
    
    // observe 就是, 添加新的回调到存储里面.
    // 一定要记住, Swfit 里面, 一个动词加闭包, 是存储这个闭包的意思.
    func observe(using callback: @escaping (Result) -> Void) {
        // If a result has already been set, call the callback directly:
        if let result = result {
            return callback(result)
        }
        callbacks.append(callback)
    }
    
    // 所谓的 Report, 就是触发每一个 Callback 对数据进行处理.
    private func report(result: Result) {
        callbacks.forEach { $0(result) }
        callbacks = []
    }
    
    func chained<T>(
        using closure: @escaping (Value) throws -> Future<T>
    ) -> Future<T> {
        // We'll start by constructing a "wrapper" promise that will be
        // returned from this method:
        let promise = Promise<T>()
        
        // Observe the current future:
        observe { result in
            switch result {
            case .success(let value):
                do {
                    // Attempt to construct a new future using the value
                    // returned from the first one:
                    let future = try closure(value)
                    
                    // Observe the "nested" future, and once it
                    // completes, resolve/reject the "wrapper" future:
                    future.observe { result in
                        switch result {
                        case .success(let value):
                            promise.resolve(with: value)
                        case .failure(let error):
                            promise.reject(with: error)
                        }
                    }
                } catch {
                    promise.reject(with: error)
                }
            case .failure(let error):
                promise.reject(with: error)
            }
        }
        
        return promise
    }
}

class Promise<Value>: Future<Value> {
    init(value: Value? = nil) {
        super.init()
        
        // If the value was already known at the time the promise
        // was constructed, we can report it directly:
        result = value.map(Result.success)
    }
    
    func resolve(with value: Value) {
        result = .success(value)
    }
    
    func reject(with error: Error) {
        result = .failure(error)
    }
}
