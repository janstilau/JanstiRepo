import UIKit
import RxSwift

class MainViewController: UIViewController {
    
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var buttonClear: UIButton!
    @IBOutlet weak var buttonSave: UIButton!
    @IBOutlet weak var itemAdd: UIBarButtonItem!
    
    private let bag = DisposeBag()
    private let images = Variable<[UIImage]>([])
    
    private var imageCache = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // throttle 的意思是, 如果有信号, 那么 0.5 内只接受一次, 发送最新的值过来. 如果没有, 就不发射了.
        // 这个逻辑, 如果用自己的 time 记录也是可以实现的, 但是 Rx 正是因为有这么多的 Operator, 才好使的.
        images.asObservable()
            .throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] photos in
                guard let preview = self?.imagePreview else { return }
                preview.image = UIImage.collage(images: photos,
                                                size: preview.frame.size)
            })
            .addDisposableTo(bag)
        
        images.asObservable()
            .subscribe(onNext: { [weak self] photos in
                self?.updateUI(photos: photos)
            })
            .addDisposableTo(bag)
        
    }
    
    private func updateUI(photos: [UIImage]) {
        buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
        buttonClear.isEnabled = photos.count > 0
        itemAdd.isEnabled = photos.count < 6
        title = photos.count > 0 ? "\(photos.count) photos" : "Collage"
    }
    
    @IBAction func actionClear() {
        images.value = []
        imageCache = []
    }
    
    @IBAction func actionSave() {
        guard let image = imagePreview.image else { return }
        
        PhotoWriter.save(image)
            .subscribe(onError: { [weak self] error in
                self?.showMessage("Error", description: error.localizedDescription)
            }, onCompleted: { [weak self] in
                self?.showMessage("Saved")
                self?.actionClear()
            })
            .addDisposableTo(bag)
    }
    
    @IBAction func actionAdd() {
        //images.value.append(UIImage(named: "IMG_1907.jpg")!)
        let photosViewController = storyboard!.instantiateViewController(
            withIdentifier: "PhotosViewController") as! PhotosViewController
        
        let newPhotos = photosViewController.selectedPhotos.share()
        
        newPhotos
            // 只读取前面六个信号的数据.
            .takeWhile { [weak self] image in
                return (self?.images.value.count ?? 0) < 6
            }
            // 只读取竖直方向上的图片数据.
            .filter { newImage in
                return newImage.size.width > newImage.size.height
            }
            // 过滤数据, 如果已经录入了, 过滤该信号.
            .filter { [weak self] newImage in
                let len = UIImagePNGRepresentation(newImage)?.count ?? 0
                guard self?.imageCache.contains(len) == false else {
                    return false
                }
                self?.imageCache.append(len)
                return true
            }
            .subscribe(onNext: { [weak self] newImage in
                guard let images = self?.images else { return }
                // 如果, 数据是想要添加的数据, 修改 PublisherObject 的值.
                // 则这个值, 会引起后面的 Subscriber 的信号接收.
                images.value.append(newImage)
            }, onDisposed: {
                print("completed photo selection")
            })
            .addDisposableTo(photosViewController.bag)
        
        
        // 当 photosViewController 退出的时候, 会发送 Complete 信号. 这个时候, 下面的 subscribe 里面的更细 UI 的方法, 才会被调用.
        newPhotos
            .ignoreElements()
            .subscribe(onCompleted: { [weak self] in
                self?.updateNavigationIcon()
            })
            .addDisposableTo(photosViewController.bag)
        
        navigationController!.pushViewController(photosViewController, animated: true)
    }
    
    private func updateNavigationIcon() {
        let icon = imagePreview.image?
            .scaled(CGSize(width: 22, height: 22))
            .withRenderingMode(.alwaysOriginal)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon,
                                                           style: .done, target: nil, action: nil)
    }
    
    func showMessage(_ title: String, description: String? = nil) {
        alert(title: title, text: description)
            .subscribe(onNext: { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            })
            .addDisposableTo(bag)
    }
}
