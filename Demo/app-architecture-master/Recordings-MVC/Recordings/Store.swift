import Foundation

/*
 final 防止子类化.
*/
final class Store {
	// 相比于 OC 中, 一个通知名, 仅仅是存放在对应类文件下的一个全局字符串, Swift 中可以将它变为这个类的一个类属性.
	static let changedNotification = Notification.Name("StoreChanged")
	// private 仅仅能在 enclosing declaration 和 extension 中用到, 这里, try! 用到了, 是因为 url 这个方法可能抛出错误.
	static private let documentDirectory = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	// swift 的单例模式.
	static let shared = Store(url: documentDirectory)
	
	/*
	Swift 里面的 static let, 自动就是懒加载的, 而且会保证线程同步问题.
	*/
	
	let baseURL: URL?
	var placeholder: URL?
	// 更改 rootFolder 的 set 的权限.
	private(set) var rootFolder: Folder
	
	init(url: URL?) {
		self.baseURL = url
		self.placeholder = nil
		if let u = url,
			let data = try? Data(contentsOf: u.appendingPathComponent(.storeLocation)), // 只要知道是某种类型, 就可以省略类型名称
			let folder = try? JSONDecoder().decode(Folder.self, from: data)
		{
			self.rootFolder = folder
		} else {
			self.rootFolder = Folder(name: "", uuid: UUID())
		}
		
		self.rootFolder.store = self
	}
	
	func fileURL(for recording: Recording) -> URL? {
		return baseURL?.appendingPathComponent(recording.uuid.uuidString + ".m4a") ?? placeholder
	}
	
	/*
	这里, 就是调用 RootFolder 的序列化方法, 然后写入到文件里面, 然后发出通知.
	可以看到, 所有的 View 事件, 最终是到达了数据层, 然后数据层保存了之后, 发出通知.
	各个 view 在接收到通知之后, 进行 view 的更新操作.
	*/
	func save(_ notifying: Item, userInfo: [AnyHashable: Any]) {
		if let url = baseURL, let data = try? JSONEncoder().encode(rootFolder) {
			try! data.write(to: url.appendingPathComponent(.storeLocation))
			// error handling ommitted
		}
		NotificationCenter.default.post(name: Store.changedNotification, object: notifying, userInfo: userInfo)
	}
	
	func item(atUUIDPath path: [UUID]) -> Item? {
		return rootFolder.item(atUUIDPath: path[0...])
	}
	
	func removeFile(for recording: Recording) {
		if let url = fileURL(for: recording), url != placeholder {
			_ = try? FileManager.default.removeItem(at: url)
		}
	}
}

// fileprivate 限制, 仅仅能在相同的源文件中可以用到.
fileprivate extension String {
	static let storeLocation = "store.json"
}
