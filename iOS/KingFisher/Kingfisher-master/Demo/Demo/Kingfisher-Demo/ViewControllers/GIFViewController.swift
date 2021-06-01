import UIKit
import Kingfisher

class GIFViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var animatedImageView: AnimatedImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = ImageLoader.gifImageURLs.last!
        
        // Should need to use different cache key to prevent data overwritten by each other.
        KF.url(url, cacheKey: "\(url)-imageview").set(to: imageView)
        
        KF.url(url, cacheKey: "\(url)-animated_imageview").set(to: animatedImageView)
    }
}
