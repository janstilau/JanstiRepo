import Foundation

class Folder: Item, Codable {
	private(set) var contents: [Item]
	override weak var store: Store? {
		didSet {
			contents.forEach { $0.store = store }
		}
	}
	
	override init(name: String, uuid: UUID) {
		contents = []
		super.init(name: name, uuid: uuid)
	}
	
	enum FolderKeys: CodingKey {
		case name,
			  uuid,
			  contents
	}
	enum FolderOrRecording: CodingKey {
		case folder,
			  recording
	}
	
	required init(from decoder: Decoder) throws {
		// 把 storage 里面顶层的 container 当做 NSDict 返回
		let c = try decoder.container(keyedBy: FolderKeys.self)
		
		contents = [Item]()
		// 取出 NSDict 里面 contents 对应的 value, 当做一个 NSArray
		var nested = try c.nestedUnkeyedContainer(forKey: .contents)
		while true {
			// 取出 NSArray 里面的一个值, 当做一个 NSDict 对待.
			let wrapper = try nested.nestedContainer(keyedBy: FolderOrRecording.self)
			// 使用 NSDict, 尝试将 folder 对应的 value, 反序列化成为 Folder
			if let f = try wrapper.decodeIfPresent(Folder.self, forKey: .folder) {
				contents.append(f)
				// 使用 NSDict, 尝试将 recording 对应的 value, 反序列化成为 Recording
			} else if let r = try wrapper.decodeIfPresent(Recording.self, forKey: .recording) {
				contents.append(r)
			} else {
				break
			}
		}
		
		let uuid = try c.decode(UUID.self, forKey: .uuid)
		let name = try c.decode(String.self, forKey: .name)
		super.init(name: name, uuid: uuid)
		
		for c in contents {
			c.parent = self
		}
	}
	
	func encode(to encoder: Encoder) throws {
		// 新建一个 NSDict, 当做顶层对象.
		var c = encoder.container(keyedBy: FolderKeys.self)
		// 将 name 序列化到 NSDict 里面, name 所对应的 key 的位置.
		try c.encode(name, forKey: .name)
		// 将 uuid 序列化到 NSDict 里面, uuid 所对应的 key 的位置.
		try c.encode(uuid, forKey: .uuid)
		// 新建一个 NSArray, 最后会将 NSArray 序列化到, contents 所对应的 key 的位置.
		var nested = c.nestedUnkeyedContainer(forKey: .contents)
		for c in contents {
			// 新建一个 NSDict, 插入到 NSArray 的最后.
			var wrapper = nested.nestedContainer(keyedBy: FolderOrRecording.self)
			switch c {
			// 将 f 序列化到 NSDict 中, folder 所在的位置.
			case let f as Folder: try wrapper.encode(f, forKey: .folder)
			// 将 r 序列化到 NSDict 中, recording 所在的位置.
			case let r as Recording: try wrapper.encode(r, forKey: .recording)
			default: break
			}
		}
		_ = nested.nestedContainer(keyedBy: FolderOrRecording.self)
	}
	
	override func deleted() {
		// 这里设计的怪怪的.
		for item in contents {
			remove(item)
		}
		super.deleted()
	}
	
	func add(_ item: Item) {
		assert(contents.contains { $0 === item } == false)
		contents.append(item)
		contents.sort(by: { $0.name < $1.name })
		let newIndex = contents.index { $0 === item }!
		item.parent = self
		store?.save(item, userInfo: [Item.changeReasonKey: Item.added, Item.newValueKey: newIndex, Item.parentFolderKey: self])
	}
	
	func reSort(changedItem: Item) -> (oldIndex: Int, newIndex: Int) {
		let oldIndex = contents.index { $0 === changedItem }!
		contents.sort(by: { $0.name < $1.name })
		let newIndex = contents.index { $0 === changedItem }!
		return (oldIndex, newIndex)
	}
	
	func remove(_ item: Item) {
		guard let index = contents.index(where: { $0 === item }) else { return }
		item.deleted()
		// 在这里, 修改了 Folder 里面 contents 的值. 这样的话, rootFolder 在存储的时候, 可以存储变化后的值.
		// 原因就在于, Folder 是一个引用值.
		contents.remove(at: index)
		// 这里, 通知存储层数据发生了改变, 存储层重新整理数据后, 存储, 然后发出通知.
		store?.save(item, userInfo: [
			Item.changeReasonKey: Item.removed,
			Item.oldValueKey: index,
			Item.parentFolderKey: self
		])
	}
	
	override func item(atUUIDPath path: ArraySlice<UUID>) -> Item? {
		guard path.count > 1 else { return super.item(atUUIDPath: path) }
		guard path.first == uuid else { return nil }
		let subsequent = path.dropFirst()
		guard let second = subsequent.first else { return nil }
		return contents.first { $0.uuid == second }.flatMap { $0.item(atUUIDPath: subsequent) }
	}
}
