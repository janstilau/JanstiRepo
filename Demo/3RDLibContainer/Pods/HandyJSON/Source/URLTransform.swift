import Foundation

open class URLTransform: TransformType {
	public typealias Object = URL
	public typealias JSON = String
	private let shouldEncodeURLString: Bool

	/**
	Initializes the URLTransform with an option to encode URL strings before converting them to an NSURL
	- parameter shouldEncodeUrlString: when true (the default) the string is encoded before passing
	to `NSURL(string:)`
	- returns: an initialized transformer
	*/
	public init(shouldEncodeURLString: Bool = true) {
		self.shouldEncodeURLString = shouldEncodeURLString
	}

	open func transformFromJSON(_ value: Any?) -> URL? {
		guard let URLString = value as? String else { return nil }

		if !shouldEncodeURLString {
			return URL(string: URLString)
		}

		guard let escapedURLString = URLString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
			return nil
		}
		return URL(string: escapedURLString)
	}

	open func transformToJSON(_ value: URL?) -> String? {
		if let URL = value {
			return URL.absoluteString
		}
		return nil
	}
}
