//
//  RootViewController.swift
//  Moody
//
//  Created by Florian on 18/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

/**
 Swift 里面, 数据和方法更多的是放到了一起, 而不是有着明显的数据和方法的分割了.
 */

class RootViewController: UIViewController, SegueHandler {
    /**
     这里, 通过 SegueIdentifier 的定义, 将 rootVC 中 SegueIdentifier 和 segueHandler 中的进行了对应.
     */
    enum SegueIdentifier: String {
        case embedNavigation = "embedNavigationController"
        case embedCamera = "embedCamera"
    }

    @IBOutlet weak var hideCameraConstraint: NSLayoutConstraint!
    var managedObjectContext: NSManagedObjectContext! // 隐式解包.

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(for: segue) {
        case .embedNavigation:
            // 在 case 的这个小区域里面, 也是可以使用 guard 的, guard 中的变量, 在整个 case 中都可以继续使用.
            guard let nc = segue.destination as? UINavigationController,
                let vc = nc.viewControllers.first as? MoodsTableViewController
            else { fatalError("wrong view controller type") }
            vc.managedObjectContext = managedObjectContext
            nc.delegate = self
        case .embedCamera:
            guard let cameraVC = segue.destination as? CameraViewController else { fatalError("must be camera view controller") }
            cameraViewController = cameraVC
            cameraViewController?.delegate = self
        }
    }


    // MARK: Private

    fileprivate var cameraViewController: CameraViewController?

    fileprivate func setCameraVisibility(_ visible: Bool) {
        hideCameraConstraint.isActive = !visible
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}


extension RootViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let cameraVisible = (viewController as? MoodDetailViewController) == nil
        setCameraVisibility(cameraVisible)
    }
}


extension RootViewController: CameraViewControllerDelegate {
    func didCapture(_ image: UIImage) {
        /**
         Context 要发生变化了, 这个变化是, 要插入一个 Mood 的数据. 在变化发生以后, 进行保存的操作.
         */
        managedObjectContext.performChanges {
            _ = Mood.insert(into: self.managedObjectContext, image: image)
        }
    }
}


