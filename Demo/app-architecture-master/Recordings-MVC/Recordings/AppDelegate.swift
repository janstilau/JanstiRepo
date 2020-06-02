import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
	
	var window: UIWindow?
	/**
	要注意, 对于 Guard 的使用, 在 Swift 里面, 是如此的普遍.
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
