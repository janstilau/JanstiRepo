import Foundation

/// Internal type which encapsulates a `MultipartFormData` upload.
final class MultipartUpload {
    lazy var result = Result { try build() }
    
    let isInBackgroundSession: Bool
    let multipartFormData: MultipartFormData
    let encodingMemoryThreshold: UInt64
    let request: URLRequestConvertible
    let fileManager: FileManager
    
    init(isInBackgroundSession: Bool,
         encodingMemoryThreshold: UInt64,
         request: URLRequestConvertible,
         multipartFormData: MultipartFormData) {
        self.isInBackgroundSession = isInBackgroundSession
        self.encodingMemoryThreshold = encodingMemoryThreshold
        self.request = request
        fileManager = multipartFormData.fileManager
        self.multipartFormData = multipartFormData
    }
    
    func build() throws -> (request: URLRequest, uploadable: UploadRequest.Uploadable) {
        var urlRequest = try request.asURLRequest()
        urlRequest.setValue(multipartFormData.contentType, forHTTPHeaderField: "Content-Type")
        
        let uploadable: UploadRequest.Uploadable
        if multipartFormData.contentLength < encodingMemoryThreshold && !isInBackgroundSession {
            let data = try multipartFormData.encode()
            
            uploadable = .data(data)
        } else {
            let tempDirectoryURL = fileManager.temporaryDirectory
            let directoryURL = tempDirectoryURL.appendingPathComponent("org.alamofire.manager/multipart.form.data")
            let fileName = UUID().uuidString
            let fileURL = directoryURL.appendingPathComponent(fileName)
            
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            
            do {
                try multipartFormData.writeEncodedData(to: fileURL)
            } catch {
                // Cleanup after attempted write if it fails.
                try? fileManager.removeItem(at: fileURL)
            }
            
            uploadable = .file(fileURL, shouldRemove: true)
        }
        
        return (request: urlRequest, uploadable: uploadable)
    }
}

extension MultipartUpload: UploadConvertible {
    func asURLRequest() throws -> URLRequest {
        try result.get().request
    }
    
    func createUploadable() throws -> UploadRequest.Uploadable {
        try result.get().uploadable
    }
}
