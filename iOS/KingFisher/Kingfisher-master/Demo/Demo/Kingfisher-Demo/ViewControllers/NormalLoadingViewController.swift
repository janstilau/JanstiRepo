import UIKit
import Kingfisher

// Basic 点击之后的跳转.

class NormalLoadingViewController: UICollectionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Loading"
        setupOperationNavigationBar()
    }
}

extension NormalLoadingViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ImageLoader.sampleImageURLs.count
    }
    
    /*
        新增了一个方法, 用于监听 cell 的移除事件.
        在这里, KF 是停止了相关 ImageView 的图片的下载工作.
     */
    override func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath)
    {
        // This will cancel all unfinished downloading task when the cell disappearing.
        (cell as! ImageCollectionViewCell).cellImageView.kf.cancelDownloadTask()
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath)
    {
        let imageView = (cell as! ImageCollectionViewCell).cellImageView!
        let url = ImageLoader.sampleImageURLs[indexPath.row]
        
        KF.url(url)
            .fade(duration: 1)
            .loadDiskFileSynchronously()
            .onProgress { (received, total) in print("\(indexPath.row + 1): \(received)/\(total)") }
            .onSuccess { print($0) }
            .onFailure { err in print("Error: \(err)") }
            .set(to: imageView)
    }
    
    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "collectionViewCell",
            for: indexPath) as! ImageCollectionViewCell
        cell.cellImageView.kf.indicatorType = .activity
        return cell
    }
}
