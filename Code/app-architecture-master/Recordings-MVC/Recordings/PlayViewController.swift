import UIKit
import AVFoundation

/*
	VC 直接和 View 进行关联.
*/
class PlayViewController: UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate {
	
	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var playButton: UIButton!
	@IBOutlet var progressLabel: UILabel!
	@IBOutlet var durationLabel: UILabel!
	@IBOutlet var progressSlider: UISlider!
	@IBOutlet var noRecordingLabel: UILabel!
	@IBOutlet var activeItemElements: UIView!
	
	// 业务 Model
	var recording: Recording? {
		didSet {
			updateViews()
		}
	}
	var audioPlayer: Player?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
		navigationItem.leftItemsSupplementBackButton = true
		updateViews()

		NotificationCenter.default.addObserver(self, selector: #selector(storeChanged(notification:)), name: Store.changedNotification, object: nil)
	}

	@objc func storeChanged(notification: Notification) {
		guard let item = notification.object as? Item, item === recording else { return }
		updateViews()
	}
	
	/*
		View 的展示逻辑, 都在此方法内, 是 UI 展示的终点.
		
	*/
	func updateViews() {
		if let r = recording, let url = r.fileURL {
			audioPlayer = Player(url: url) { [weak self] time in
				if let t = time {
					self?.updateProgress(progress: t, duration: self?.audioPlayer?.duration ?? 0)
				} else {
					self?.recording = nil
				}
			}
			
			if let ap = audioPlayer {
				updateProgress(progress: 0, duration: ap.duration)
				title = r.name
				nameTextField?.text = r.name
				activeItemElements?.isHidden = false
				noRecordingLabel?.isHidden = true
			} else {
				recording = nil
			}
		} else {
			updateProgress(progress: 0, duration: 0)
			audioPlayer = nil
			activeItemElements?.isHidden = true
			noRecordingLabel?.isHidden = false
			title = ""
		}
	}
	
	func updateProgress(progress: TimeInterval, duration: TimeInterval) {
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
	
	/*
		ViewAction, VC 进行 Model 层改动, 然后 Model 修改之后发出通知, VC 接受通知, 进行整个 View 的 Update
		目前该 App 是单项数据留
	*/
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

// 使用 Extension + private 的方法, 定义了私有常量.
fileprivate extension String {
	static let uuidPathKey = "uuidPath"
	static let pause = NSLocalizedString("Pause", comment: "")
	static let resume = NSLocalizedString("Resume playing", comment: "")
	static let play = NSLocalizedString("Play", comment: "")
}
