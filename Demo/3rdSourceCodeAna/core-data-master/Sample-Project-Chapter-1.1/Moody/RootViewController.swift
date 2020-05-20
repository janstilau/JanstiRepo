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

class RootViewController: UIViewController, SeguePerformer {
    /*
     SeguePerformer 中真正需要实现类实现的, 也就是 SegueIdentifier 的实现, 相比较于 typealiase, 这里是直接定义了这样的一个类. 那么, rootVC 这个类, 也就符合了 SeguePerformer 这个 协议. 这个协议里面定义了几个方法, RootVc 符合限制, 所以就可以拿来使用了.
     */
    enum SegueIdentifier: String {
        case embedNavigation = "embedNavigationController"
        case embedCamera = "embedCamera"
    }
    
    @IBOutlet weak var hideCameraConstraint: NSLayoutConstraint!
    var managedObjectContext: NSManagedObjectContext!
    
    // 这里其实就是传递 manageContext 的过程. 不过, 这里有着大量的 as 类型判断, 难道 swift 里面就不用考虑依赖的问题吗.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(for: segue) {
        case .embedNavigation:
            guard let nc = segue.destination as? UINavigationController,
                let vc = nc.viewControllers.first as? ManageContextContainer
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
}


extension RootViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let cameraVisible = (viewController as? MoodDetailViewController) == nil
        setCameraVisibility(cameraVisible)
    }
    func setCameraVisibility(_ visible: Bool) {
        hideCameraConstraint.isActive = !visible
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

// CameraViewControllerDelegate 的内容, 放到了 extension 里面, 和其他的代码逻辑进行分离.
extension RootViewController: CameraViewControllerDelegate {
    func didCapture(_ image: UIImage) {
        managedObjectContext.performChanges {
            _ = Mood.insert(into: self.managedObjectContext, image: image)
        }
    }
}


