import Alamofire
import UIKit

class DetailViewController: UITableViewController {
    enum Sections: Int {
        case headers, body
    }

    /*
     didSet 是为类的设计者准备的, 在 didSet 里面, 做值改变的后续处理.
     原来 OC 里面, 在 set 方法里面做相应的逻辑. 程序员要做值的存储, 和后续处理两种逻辑. 在 Swift 里面, 专门作出一个区域, 明确了后续处理应该写到这里.
     相应的, 计算属性和存储属性分割的更加明显了. 计算属性, 不会有 didSet, willSet, 存储属性的存储过程, 语言自己维护.
     */
    var request: Request? {
        didSet {
            oldValue?.cancel()
            title = request?.description
            refreshControl?.endRefreshing()
            headers.removeAll()
            body = nil
            elapsedTime = nil
        }
    }

    var headers: [String: String] = [:]
    var body: String?
    var elapsedTime: TimeInterval?
    var segueIdentifier: String?

    /*
     类属性, 默认就是懒加载的.
     属性的初始化, 和属性的定义放在了一起, 让代码布局更加统一.
     少了 initialize, load 里面方法的调用.
     */
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: View Lifecycle

    /*
     OptionSet 这个协议, 就是为了避免所有的 enum 都是 Int 表示.
     让一个单独的类型, 作为各个类型的 Option 表示, 各个可能表示的值, 通过类型的 static 属性获取, 而不是 Int 值的表示. 这样, 避免出错.
     */
    override func awakeFromNib() {
        super.awakeFromNib()
        /*
         Swift 里面, 尊崇了重构里面, 类型系统的定义. 原本简单的枚举值, 现在被类型管理, 通过静态方法, 获取到合适的值.
         */
        refreshControl?.addTarget(self, action: #selector(DetailViewController.refresh), for: .valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }

    // MARK: IBActions

    @IBAction func refresh() {
        guard let request = request else {
            return
        }

        refreshControl?.beginRefreshing()

        let start = CACurrentMediaTime()

        let requestComplete: (HTTPURLResponse?, Result<String, AFError>) -> Void = { response, result in
            let end = CACurrentMediaTime()
            self.elapsedTime = end - start

            if let response = response {
                for (field, value) in response.allHeaderFields {
                    self.headers["\(field)"] = "\(value)"
                }
            }

            if let segueIdentifier = self.segueIdentifier {
                switch segueIdentifier {
                case "GET", "POST", "PUT", "DELETE":
                    if case let .success(value) = result { self.body = value }
                case "DOWNLOAD":
                    self.body = self.downloadedBodyString()
                default:
                    break
                }
            }

            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }

        if let request = request as? DataRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        } else if let request = request as? DownloadRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        }
    }

    private func downloadedBodyString() -> String {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        do {
            let contents = try fileManager.contentsOfDirectory(at: cachesDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            if let fileURL = contents.first, let data = try? Data(contentsOf: fileURL) {
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

                if let prettyString = String(data: prettyData, encoding: String.Encoding.utf8) {
                    try fileManager.removeItem(at: fileURL)
                    return prettyString
                }
            }
        } catch {
            // No-op
        }

        return ""
    }
}

// MARK: - UITableViewDataSource

extension DetailViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .headers:
            return headers.count
        case .body:
            return body == nil ? 0 : 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)! {
        case .headers:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Header")!
            let field = headers.keys.sorted(by: <)[indexPath.row]
            let value = headers[field]

            cell.textLabel?.text = field
            cell.detailTextLabel?.text = value

            return cell
        case .body:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Body")!
            cell.textLabel?.text = body

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DetailViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return ""
        }

        switch Sections(rawValue: section)! {
        case .headers:
            return "Headers"
        case .body:
            return "Body"
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections(rawValue: indexPath.section)! {
        case .body:
            return 300
        default:
            return tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if Sections(rawValue: section) == .body, let elapsedTime = elapsedTime {
            let elapsedTimeText = DetailViewController.numberFormatter.string(from: elapsedTime as NSNumber) ?? "???"
            return "Elapsed Time: \(elapsedTimeText) sec"
        }

        return ""
    }
}
