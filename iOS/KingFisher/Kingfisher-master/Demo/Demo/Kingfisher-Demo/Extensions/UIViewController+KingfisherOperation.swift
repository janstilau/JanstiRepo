
import UIKit
import Kingfisher

protocol MainDataViewReloadable {
    func reload()
}

extension UITableViewController: MainDataViewReloadable {
    func reload() {
        tableView.reloadData()
    }
}

extension UICollectionViewController: MainDataViewReloadable {
    func reload() {
        collectionView.reloadData()
    }
}

protocol KingfisherActionAlertPopup {
    func alertPopup(_ sender: Any) -> UIAlertController
}

func cleanCacheAction() -> UIAlertAction {
    return UIAlertAction(title: "Clean Cache", style: .default) { _ in
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache()
    }
}

func reloadAction(_ reloadable: MainDataViewReloadable) -> UIAlertAction {
    return UIAlertAction(title: "Reload", style: .default) { _ in
        reloadable.reload()
    }
}

let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

func createAlert(_ sender: Any, actions: [UIAlertAction]) -> UIAlertController {
    let alert = UIAlertController(title: "Action", message: nil, preferredStyle: .actionSheet)
    alert.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
    alert.popoverPresentationController?.permittedArrowDirections = .any
    
    actions.forEach { alert.addAction($0) }
    
    return alert
}

extension UIViewController: KingfisherActionAlertPopup {
    @objc func alertPopup(_ sender: Any) -> UIAlertController {
        let alert = createAlert(sender, actions: [cleanCacheAction(), cancelAction])
        if let r = self as? MainDataViewReloadable {
            alert.addAction(reloadAction(r))
        }
        return alert
    }
}

extension UIViewController  {
    func setupOperationNavigationBar() {
        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Action", style: .plain, target: self, action: #selector(performKingfisherAction))
    }
    
    @objc func performKingfisherAction(_ sender: Any) {
        present(alertPopup(sender), animated: true)
    }
}
