//
//  LBFMFindCell.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/2/28.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit

class LBFMFindCell: UICollectionViewCell {
    
    /*
     iOS 的项目里面, 大量使用了懒加载, 不过在我的代码里面, 为了代码的逻辑清晰, 一般都在开头进行 Setup.
     Swfit 里面的 lazy 方式, 使得懒加载又重新变为了一种优雅的方式.
     */
    private lazy var imageView : UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    private lazy var titleLabel : UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = NSTextAlignment.center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(self.imageView)
        self.imageView.snp.makeConstraints { (make) in
            make.height.width.equalTo(45)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
        }
        
        self.addSubview(self.titleLabel)
        self.titleLabel.snp.makeConstraints { (make) in
            make.left.right.equalToSuperview()
            make.top.equalTo(self.imageView.snp.bottom).offset(10)
            make.height.equalTo(20)
        }
    }
    
    // 这里感觉有点问题啊, 命名不需要, 还是要定义一下.
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // 属性的 set 之后, 要进行 UI 的更新操作, 一般都用 didSet 进行, 这里感觉, 这样属性和代码的位置就不固定了. 岂不是到处都有属性了.
    // 这样倒也是一种好处, 那就是, 属性和方法离得更加紧密了, 只不过和之前语言的感觉不太一样了. 经典的语言, 都是成员变量, 专门在一个地方.
    var dataString: String? {
        didSet {
            self.titleLabel.text = dataString
            self.imageView.image = UIImage(named: dataString!) // 由于,  UIImage(named )可能返回 nil, 所以 ImageView 的 image 是一个 optional
        }
    }
}
