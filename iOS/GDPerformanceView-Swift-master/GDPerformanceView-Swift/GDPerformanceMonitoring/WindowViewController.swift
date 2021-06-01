import UIKit

// MARK: Class Definition

/// A window controller to override the properties of the status bar so that developers can choose their own preferences.
internal class WindowViewController: UIViewController, StatusBarConfigurator {
    
    // MARK: Public Properties
    
    /// Overrides prefersStatusBarHidden.
    public var statusBarHidden = false {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    /// Overrides preferredStatusBarStyle.
    public var statusBarStyle = UIStatusBarStyle.default {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // MARK: Properties Overriders
    
    override var prefersStatusBarHidden: Bool {
        get {
            return self.statusBarHidden
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return self.statusBarStyle
        }
    }
    
    // MARK: Init Methods & Superclass Overriders
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
    }
}
