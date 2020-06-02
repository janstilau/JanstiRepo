import UIKit

class FolderViewController: UITableViewController {
	/*
	默认是根 Folder, 这里, 设置了监听, 在改变之后进行 tableView 的重绘操作, 并且更改自己的 title.
	
	willSet, didSet 更多的是为了类的设计者进行准备的.
	OC 里面, setVlue 里面, 进行后续的操作, 其实是将 值改变和后续处理混在了一起, 专门分出来, 有利于代码更加清晰.
	*/
	var folder: Folder = Store.shared.rootFolder {
		didSet {
			tableView.reloadData()
			if folder === Store.shared.rootFolder {
				title = .recordings // 这里, 因为知道, 一定会是 String, 所以可以用 String.recordings 来写, 其中, String 可以省略.
			} else {
				title = folder.name
			}
		}
	}
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftItemsSupplementBackButton = true
		navigationItem.leftBarButtonItem = editButtonItem
		
		/*
		在这里, 通过 OC 的方式进行通知的绑定, 所以要进行 #selector 的标识.
		*/
		NotificationCenter.default.addObserver(self, selector: #selector(handleChangeNotification(_:)), name: Store.changedNotification, object: nil)
	}
	
	@objc func handleChangeNotification(_ notification: Notification) {
		// Handle changes to the current folder
		if let item = notification.object as? Folder, item === folder {
			let reason = notification.userInfo?[Item.changeReasonKey] as? String
			if reason == Item.removed, let nc = navigationController {
				nc.setViewControllers(nc.viewControllers.filter { $0 !== self }, animated: false)
			} else {
				folder = item
			}
		}
		
		// Handle changes to children of the current folder
		guard let userInfo = notification.userInfo, userInfo[Item.parentFolderKey] as? Folder === folder else {
			return
		}
		
		// Handle changes to contents
		if let changeReason = userInfo[Item.changeReasonKey] as? String {
			let oldValue = userInfo[Item.newValueKey]
			let newValue = userInfo[Item.oldValueKey]
			switch (changeReason, newValue, oldValue) {
			case let (Item.removed, _, (oldIndex as Int)?):
				tableView.deleteRows(at: [IndexPath(row: oldIndex, section: 0)], with: .right)
			case let (Item.added, (newIndex as Int)?, _):
				tableView.insertRows(at: [IndexPath(row: newIndex, section: 0)], with: .left)
			case let (Item.renamed, (newIndex as Int)?, (oldIndex as Int)?):
				tableView.moveRow(at: IndexPath(row: oldIndex, section: 0), to: IndexPath(row: newIndex, section: 0))
				tableView.reloadRows(at: [IndexPath(row: newIndex, section: 0)], with: .fade)
			default: tableView.reloadData()
			}
		} else {
			tableView.reloadData()
		}
	}
	
	var selectedItem: Item? {
		if let indexPath = tableView.indexPathForSelectedRow {
			return folder.contents[indexPath.row]
		}
		return nil
	}
	
	// MARK: - Segues and actions
	
	@IBAction func createNewFolder(_ sender: Any?) {
		modalTextAlert(title: .createFolder, accept: .create, placeholder: .folderName) { string in
			if let s = string {
				let newFolder = Folder(name: s, uuid: UUID())
				self.folder.add(newFolder)
			}
			self.dismiss(animated: true)
		}
	}
	
	@IBAction func createNewRecording(_ sender: Any?) {
		performSegue(withIdentifier: .showRecorder, sender: self)
	}
	
	/*
	用 StoryBoard, 带来了编码不方便.
	*/
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier else { return }
		if identifier == .showFolder {
			guard
				let folderVC = segue.destination as? FolderViewController,
				let selectedFolder = selectedItem as? Folder
				else { fatalError() }
			folderVC.folder = selectedFolder
		}
		else if identifier == .showRecorder {
			guard let recordVC = segue.destination as? RecordViewController else { fatalError() }
			recordVC.folder = folder
		} else if identifier == .showPlayer {
			guard
				let playVC = (segue.destination as? UINavigationController)?.topViewController as? PlayViewController,
				let recording = selectedItem as? Recording
				else { fatalError() }
			playVC.recording = recording
			if let indexPath = tableView.indexPathForSelectedRow {
				tableView.deselectRow(at: indexPath, animated: true)
			}
		}
	}
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return folder.contents.count
	}
	

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = folder.contents[indexPath.row]
		let identifier = item is Recording ? "RecordingCell" : "FolderCell"
		let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
		cell.textLabel!.text = "\((item is Recording) ? "🔊" : "📁")  \(item.name)"
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		folder.remove(folder.contents[indexPath.row])
	}
}

/*
这应该算是, 之前的 Static const NSString * 的 Swfit 的写法了.
首先, filePrivate 其实就是等同于 Static. 因为有它的存在, 里面的各个定义, 其实并不会污染到全局.
其次, 定义在 String 的 extension 里面, 不用进行类型的定义了.
所以, 这种常量定义的方式, 会是 Swift 里面的标配.
*/
fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	static let showRecorder = "showRecorder"
	static let showPlayer = "showPlayer"
	static let showFolder = "showFolder"
	
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
}

