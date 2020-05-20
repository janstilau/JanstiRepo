import Alamofire
import UIKit

class MasterViewController: UITableViewController {
    // MARK: - Properties

    @IBOutlet var titleImageView: UIImageView!

    var detailViewController: DetailViewController?
    var objects = NSMutableArray() // 这里, 直接就可以这样进行初始化操作.

    private var reachability: NetworkReachabilityManager!

    // MARK: - View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        navigationItem.titleView = titleImageView
        clearsSelectionOnViewWillAppear = true

        reachability = NetworkReachabilityManager.default
        monitorReachability()
    }

    // MARK: - UIStoryboardSegue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if
            let navigationController = segue.destination as? UINavigationController,
            let detailViewController = navigationController.topViewController as? DetailViewController {
            func requestForSegue(_ segue: UIStoryboardSegue) -> Request? {
                switch segue.identifier! {
                case "GET":
                    detailViewController.segueIdentifier = "GET"
                    return AF.request("https://httpbin.org/get")
                case "POST":
                    detailViewController.segueIdentifier = "POST"
                    return AF.request("https://httpbin.org/post", method: .post)
                case "PUT":
                    detailViewController.segueIdentifier = "PUT"
                    return AF.request("https://httpbin.org/put", method: .put)
                case "DELETE":
                    detailViewController.segueIdentifier = "DELETE"
                    return AF.request("https://httpbin.org/delete", method: .delete)
                case "DOWNLOAD":
                    detailViewController.segueIdentifier = "DOWNLOAD"
                    let destination = DownloadRequest.suggestedDownloadDestination(for: .cachesDirectory,
                    return AF.download("https://httpbin.org/stream/1", to: destination)
                default:
                    return nil
                }
            }

            if let request = requestForSegue(segue) {
                detailViewController.request = request
            }
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 ,
            indexPath.row == 0 {
            print("Reachability Status: \(reachability.status)")
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - Private - Reachability

    private func monitorReachability() {
        reachability.startListening { status in
            print("Reachability Status Changed: \(status)")
        }
    }
}
