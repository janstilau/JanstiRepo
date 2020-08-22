import Foundation

public extension URLRequest {
    /// Returns the `httpMethod` as Alamofire's `HTTPMethod` type.
    var method: HTTPMethod? {
        get { httpMethod.flatMap(HTTPMethod.init) }
        set { httpMethod = newValue?.rawValue }
    }
    
    func validate() throws {
        if method == .get, let bodyData = httpBody {
            throw AFError.urlRequestValidationFailed(reason: .bodyDataInGETRequest(bodyData))
        }
    }
}
