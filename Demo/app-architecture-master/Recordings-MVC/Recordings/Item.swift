import Foundation

class Item {
	let uuid: UUID // 唯一标识.
	private(set) var name: String //名字, 只读属性, 只能够通过初始化来设置.
	weak var store: Store? // 这里, 感觉这个没有多大作用, 直接用单例不更好.
	weak var parent: Folder? {
		didSet {
			store = parent?.store
		}
	}
	
	init(name: String, uuid: UUID) {
		self.name = name
		self.uuid = uuid
		self.store = nil
	}
	
	/*
	每一次名字的修改, 都要进行保存操作.
	*/
	func setName(_ newName: String) {
		name = newName
		if let p = parent {
			let (oldIndex, newIndex) = p.reSort(changedItem: self)
			store?.save(self, userInfo:
				[Item.changeReasonKey: Item.renamed,
				 Item.oldValueKey: oldIndex,
				 Item.newValueKey: newIndex,
				 Item.parentFolderKey: p])
		}
	}
	
	func deleted() {
		parent = nil
	}
	
	var uuidPath: [UUID] {
		var path = parent?.uuidPath ?? []
		path.append(uuid)
		return path
	}
	
	func item(atUUIDPath path: ArraySlice<UUID>) -> Item? {
		guard let first = path.first, first == uuid else { return nil }
		return self
	}
}

extension Item {
	static let changeReasonKey = "reason"
	static let newValueKey = "newValue"
	static let oldValueKey = "oldValue"
	static let parentFolderKey = "parentFolder"
	static let renamed = "renamed"
	static let added = "added"
	static let removed = "removed"
}

