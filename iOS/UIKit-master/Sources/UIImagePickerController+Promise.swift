#if !PMKCocoaPods
import PromiseKit
#endif
import UIKit

#if !os(tvOS)

extension UIViewController {
    /// Presents the UIImagePickerController, resolving with the user action.
    public func promise(_ vc: UIImagePickerController,
                        animate: PMKAnimationOptions = [.appear, .disappear],
                        completion: (() -> Void)? = nil) -> Promise<[UIImagePickerController.InfoKey: Any]> {
        let animated = animate.contains(.appear)
        let proxy = UIImagePickerControllerProxy()
        vc.delegate = proxy
        present(vc, animated: animated, completion: completion)
        return proxy.promise.ensure {
            vc.presentingViewController?.dismiss(animated: animated, completion: nil)
        }
    }
}

@objc private class UIImagePickerControllerProxy: NSObject,
                                                  UIImagePickerControllerDelegate,
                                                  UINavigationControllerDelegate {
    let (promise, seal) = Promise<[UIImagePickerController.InfoKey: Any]>.pending()
    var retainCycle: AnyObject?

    required override init() {
        super.init()
        // 自己引用自己, 保证不会消失.
        // 然后在特定的时间节点, 打破这个引用.
        retainCycle = self
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // 当, 有值的时候, 就将 promise 状态, 设置为 sealed->fullfilled
        // 然后打破循环
        seal.fulfill(info)
        retainCycle = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // 当, 取消的是偶, 就将 promise 状态, 设置为 sealed->reject
        // 然后打破循环
        seal.reject(UIImagePickerController.PMKError.cancelled)
        retainCycle = nil
    }
}

extension UIImagePickerController {
    /// Errors representing PromiseKit UIImagePickerController failures
    public enum PMKError: CancellableError {
        /// The user cancelled the UIImagePickerController.
        case cancelled
        /// - Returns: true
        public var isCancelled: Bool {
            switch self {
            case .cancelled:
                return true
            }
        }
    }
}

#endif
