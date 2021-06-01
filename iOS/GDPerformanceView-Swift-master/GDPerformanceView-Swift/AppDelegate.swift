import UIKit

/*
 Windows work with your view controllers to handle events and to perform many other tasks that are fundamental to your app’s operation.
 UIKit handles most window-related interactions, working with other objects as needed to implement many app behaviors.

 You use windows only when you need to do the following:

 Provide a main window to display your app’s content. // 最主要的需求

 Create additional windows (as needed) to display additional content. // 目前这个类库所做

 Normally, Xcode provides your app's main window. New iOS projects use storyboards to define the app’s views. Storyboards require the presence of a window property on the app delegate object, which the Xcode templates automatically provide. If your app does not use storyboards, you must create this window yourself.

 Most apps need only one window, which displays the app’s content on the device’s main screen.
 Although you can create additional windows on the device’s main screen, extra windows are commonly used to display content on an external screen, as described in Displaying Content on a Connected Screen.

 You also use UIWindow objects for a handful of other tasks:

 Setting the z-axis level of your window, which affects the visibility of the window relative to other windows.

 Showing windows and making them the target of keyboard events.

 Converting coordinate values to and from the window’s coordinate system.

 Changing the root view controller of a window.

 Changing the screen on which the window is displayed.

 Windows do not have any visual appearance of their own.
 Instead, a window hosts one or more views, which are managed by the window's root view controller.
 You configure the root view controller in your storyboards, adding whatever views are appropriate for your interface.

 You should rarely need to subclass UIWindow. The kinds of behaviors you might implement in a window can usually be implemented in a higher-level view controller more easily. One of the few times you might want to subclass is to override the becomeKey() or resignKey() methods to implement custom behaviors when a window’s key status changes. For information about how to display a window on a specific screen, see UIScreen.

 Understanding Keyboard Interactions
 Whereas touch events are delivered to the window where they occurred, events that do not have a relevant coordinate value are delivered to the key window. Only one window at a time can be the key window, and you can use a window’s isKeyWindow property to determine its status. Most of the time, your app’s main window is the key window, but UIKit may designate a different window as needed.

 If you need to know which window is key, observe the didBecomeKeyNotification and didResignKeyNotification notifications. The system sends those notifications in response to key window changes in your app. To force a window become key, or to force a window to resign the key status, call the appropriate methods of this class.
 */

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var performanceView: PerformanceMonitor?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
    #if DEBUG
        PerformanceMonitor.shared().start()
    #endif

        return true
    }
}
