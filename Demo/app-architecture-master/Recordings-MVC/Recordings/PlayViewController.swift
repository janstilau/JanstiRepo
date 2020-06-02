import UIKit
import AVFoundation

class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	var audioPlayer: Player?
	var recording: Recording? {
		didSet {
			updateViews()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
		
		updateViews()
	}
	
	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateViews()
	}
	
	func updateViews() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] time in
				if let t = time {
					self?.updateProgressDisplays(progress: t, duration: self?.audioPlayer?.duration ?? 0)
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				updateProgressDisplays(progress: 0, duration: ap.duration)
				title = r.name
				nameTextField?.text = r.name
				activeItemElements?.isHidden = false
				noRecordingLabel?.isHidden = true
			} else {
				recording = nil
			}
		} else {
			updateProgressDisplays(progress: 0, duration: 0)
			audioPlayer = nil
			title = ""
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
		}
	}
	
	func updateProgressDisplays(progress: TimeInterval, duration: TimeInterval) {
		progressLabel?.text = timeString(progress)
		durationLabel?.text = timeString(duration)
		progressSlider?.maximumValue = Float(duration)
		progressSlider?.value = Float(progress)
		updatePlayButton()
	}
	
	func updatePlayButton() {
		if audioPlayer?.isPlaying == true {
			playButton?.setTitle(.pause, for: .normal)
		} else if audioPlayer?.isPaused == true {
			playButton?.setTitle(.resume, for: .normal)
		} else {
			playButton?.setTitle(.play, for: .normal)
		}
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		if let r = recording, let text = textField.text {
			r.setName(text)
			title = r.name
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
	@IBAction func setProgress() {
		guard let s = progressSlider else { return }
		audioPlayer?.setProgress(TimeInterval(s.value))
	}
	
	@IBAction func play() {
		audioPlayer?.togglePlay()
		updatePlayButton()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		recording = nil
	}
	
	// MARK: UIStateRestoring
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		coder.encode(recording?.uuidPath, forKey: .uuidPathKey)
	}
	
	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)
		if let uuidPath = coder.decodeObject(forKey: .uuidPathKey) as? [UUID], let recording = Store.shared.item(atUUIDPath: uuidPath) as? Recording {
			self.recording = recording
		}
	}
}

fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}

/*
	这里, String 里面, 增加了很多的私有属性, 而 showRecorder 其实在 FolderViewController 里面, 进行了定义, 但是, 由于 FilePrivate 的存在, 这里可以进行重复的定义.
*/
fileprivate extension String {
	static let showRecorder = "showRecorder"
	static let showPlayer = "showPlayer"
	static let showFolder = "showFolder"
	
	static let recordings = NSLocalizedString("Recordings", comment: "Heading for the list of recorded audio items and folders.")
	static let createFolder = NSLocalizedString("Create Folder", comment: "Header for folder creation dialog")
	static let folderName = NSLocalizedString("Folder Name", comment: "Placeholder for text field where folder name should be entered.")
	static let create = NSLocalizedString("Create", comment: "Confirm button for folder creation dialog")
}
