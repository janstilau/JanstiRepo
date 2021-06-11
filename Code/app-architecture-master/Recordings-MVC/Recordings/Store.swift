import Foundation


/*
序列话层的工具类.
*/
final class Store {
	
	static let shared = Store(url: documentDirectory)
	static let changedNotification = Notification.Name("StoreChanged")
	static private let documentDirectory = try! FileManager.default.url(for: .libraryDirectory,
																							  in: .userDomainMask,
																							  appropriateFor: nil,
																							  create: true)
	
	let baseURL: URL?
	var placeholder: URL?
	private(set) var rootFolder: Folder
	
	init(url: URL?) {
		self.baseURL = url
		self.placeholder = nil
		
		if let u = url,
			let data = try? Data(contentsOf: u.appendingPathComponent(.storeLocation)),
			let folder = try? JSONDecoder().decode(Folder.self, from: data)
		{
			self.rootFolder = folder
		} else {
			self.rootFolder = Folder(name: "", uuid: UUID())
		}
		
		self.rootFolder.store = self
		
		print(Store.documentDirectory)
	}
	
	// 所有的录音文件, 其实是放到了一起的.
	// 目录关系, 是按照 state.json 里面的 json 结构完成的.
	// 想要拿到真正的录音文件的位置, 直接使用 baseURL, 拼接 uuid 和后缀名就可以.
	func fileURL(for recording: Recording) -> URL? {
		return baseURL?.appendingPathComponent(recording.uuid.uuidString + ".m4a") ?? placeholder
	}
	
	func save(_ updated: Item, userInfo: [AnyHashable: Any]) {
		if let url = baseURL,
			let data = try? JSONEncoder().encode(rootFolder) {
			try! data.write(to: url.appendingPathComponent(.storeLocation))
		}
		NotificationCenter.default.post(name: Store.changedNotification, object: updated, userInfo: userInfo)
	}
	
	func item(atUUIDPath path: [UUID]) -> Item? {
		return rootFolder.item(atUUIDPath: path[0...])
	}
	
	func removeFile(for recording: Recording) {
		if let url = fileURL(for: recording),
			url != placeholder {
			_ = try? FileManager.default.removeItem(at: url)
		}
	}
}

fileprivate extension String {
	static let storeLocation = "store.json"
}
