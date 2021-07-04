import UIKit
import RxSwift
import RxCocoa
import Kingfisher

func cachedFileURL(_ fileName: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
    
    private let repo = "ReactiveX/RxSwift"
    
    fileprivate let events = Variable<[Event]>([])
    fileprivate let bag = DisposeBag()
    
    private let eventsFileURL = cachedFileURL("events.plist")
    private let modifiedFileURL = cachedFileURL("modified.txt")
    fileprivate let lastModified = Variable<NSString?>(nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = repo
        
        self.refreshControl = UIRefreshControl()
        let refreshControl = self.refreshControl!
        refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        // 在 ViewDidLoad 里面, 加载了存储的数据, 让用户首次进入之后, 就可以看到数据构建好的界面.
        let eventsArray = (NSArray(contentsOf: eventsFileURL)
                            as? [[String: Any]]) ?? []
        events.value = eventsArray.flatMap(Event.init)
        
        lastModified.value = try? NSString(contentsOf: modifiedFileURL, usedEncoding: nil)
        
        refresh()
    }
    
    func refresh() {
        fetchEvents(repo: repo)
    }
    
    // 如果, 使用开始一个网络请求的方式, 创建出一个事件序列来.
    // 这种写法, 不再是指令式的写法, 而是数据流转的方式.
    func fetchEvents(repo: String) {
        let response = Observable.from([repo])
            // 从一个 String, 构建出一个 Url
            .map { urlString -> URL in
                return URL(string: "https://api.github.com/repos/\(urlString)/events")!
            }
            // 从一个 Url, 构建出一个 Request.
            .map { [weak self] url -> URLRequest in
                var request = URLRequest(url: url)
                if let modifiedHeader = self?.lastModified.value {
                    request.addValue(modifiedHeader as String,
                                     forHTTPHeaderField: "Last-Modified")
                }
                return request
            }
            // URLRequest 传递到 flatMap 里面, 返回一个新的事件序列.
            // 这个新的事件序列返回的结构, 发送给后面的 subscrie
            // flatMap 是一个非常重要的东西, 前面的操作都是数据的变化.
            // 而 FlatMap 则是开启另外的一个异步操作.
            .flatMap { request -> Observable<(HTTPURLResponse, Data)> in
                return URLSession.shared.rx.response(request: request)
            }
            .shareReplay(1)
        
        response
            // 首先, 是过滤操作. 只接受正常范围的值.
            .filter { response, _ in
                // Range 的这个操作符, 就是 contans 判断.
                return 200..<300 ~= response.statusCode
            }
            // 然后把 data 数据, 变为正常的 Dict 数据.
            .map { _, data -> [[String: Any]] in
                guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                      let result = jsonObject as? [[String: Any]] else {
                    return []
                }
                return result
            }
            .filter { objects in
                return objects.count > 0
            }
            // 最后, 通过 dict 变化为 Model.
            .map { objects in
                return objects.flatMap(Event.init)
            }
            .subscribe(onNext: { [weak self] newEvents in
                self?.processEvents(newEvents)
            })
            .addDisposableTo(bag)
        
        // 对于, 一个 Response 如果里面有 Last-modified 数据, 需要在当前的 VC 里面存储起来.
        // 这件事情的处理代码, 和得到 Response 里面的数据, 解析之后更新 UI 分开了.
        // 这在命令式的代码世界里面, 铁定就在一个 Block 里面就可以了.
        response
            .filter {response, _ in
                return 200..<400 ~= response.statusCode
            }
            // FlatMap 使用的优势在于, 可以自己控制里面的行为.
            .flatMap { response, _ -> Observable<NSString> in
                guard let value = response.allHeaderFields["Last-Modified"]  as? NSString else {
                    return Observable.never()
                }
                return Observable.just(value)
            }
            .subscribe(onNext: { [weak self] modifiedHeader in
                guard let strongSelf = self else { return }
                strongSelf.lastModified.value = modifiedHeader
                try? modifiedHeader.write(to: strongSelf.modifiedFileURL, atomically: true,
                                          encoding: String.Encoding.utf8.rawValue)
            })
            .addDisposableTo(bag)
    }
    
    func processEvents(_ newEvents: [Event]) {
        var updatedEvents = newEvents + events.value
        if updatedEvents.count > 50 {
            updatedEvents = Array<Event>(updatedEvents.prefix(upTo: 50))
        }
        
        events.value = updatedEvents
        tableView.reloadData()
        refreshControl?.endRefreshing()
        
        let eventsArray = updatedEvents.map{ $0.dictionary } as NSArray
        eventsArray.write(to: eventsFileURL, atomically: true)
        
    }
    
    // MARK: - Table Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = events.value[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = event.name
        cell.detailTextLabel?.text = event.repo + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
        cell.imageView?.kf.setImage(with: event.imageUrl, placeholder: UIImage(named: "blank-avatar"))
        return cell
    }
}
