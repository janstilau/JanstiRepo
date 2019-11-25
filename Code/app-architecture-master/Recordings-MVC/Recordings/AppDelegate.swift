import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
	
	var window: UIWindow?
	/**
	* guard 这个语言层面上提供的关键字, 是语言层面上, 对于防卫式写法的一次加强. 因为判断, 然后提前退出这个操作实在是太普遍了, 所以语言层面增加了对于这个的支持.
	*/
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		guard let rootViewController = window?.rootViewController else {
			assert(false, "window have no rootViewControoler")
			return false
		}
		guard let splitViewController = rootViewController as? UISplitViewController else {
			assert(false, "rootViewController is not a UISplitViewController")
			return false
		}
		splitViewController.delegate = self
		splitViewController.preferredDisplayMode = .allVisible
		return true
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
		guard let topAsDetailController = (secondaryViewController as? UINavigationController)?.topViewController as? PlayViewController else { return false }
		if topAsDetailController.recording == nil {
			// Don't include an empty player in the navigation stack when collapsed
			return true
		}
		return false
	}
	
	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return true
	}
	
	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
		return true
	}
}
