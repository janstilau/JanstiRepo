import Foundation

public extension URLRequest {
    // URLRequest 提供了对于自定义类型 HTTPMethod 的适配
    var method: HTTPMethod? {
        get { httpMethod.flatMap(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }

    /*
     目前来说, 对于原生的 URLRequest 仅仅有一种验证的逻辑, 就是下面的 get 和 bodyData 同时出现的时候.
     */
    func validate() throws {
        if method == .get,
            let bodyData = httpBody {
            throw AFError.urlRequestValidationFailed(reason: .bodyDataInGETRequest(bodyData))
        }
    }
}
