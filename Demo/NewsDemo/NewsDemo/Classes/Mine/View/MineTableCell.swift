//
//  MineTableCell.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

class MineTableCell: UITableViewCell {
    /// 头像
    @IBOutlet weak var avatarImageView: UIImageView!
    
    @IBOutlet weak var vipImageView: UIImageView!
    /// 用户名
    @IBOutlet weak var nameLabel: UILabel!
    /// 新通知
    @IBOutlet weak var tipsButton: UIButton!
    
    /*
     原有的 OC 里面, 是 setConcern 方法后, 进行 UI 的更新操作, 在 Swift 里面, 就是在属性的 didSet 方法里面, 进行后续的操作. 会不会导致, 代码和属性定义的代码混合在一起.
     */
    var myConcern: MyConcern? {
        didSet {
            nameLabel.text = myConcern?.name
            if let isVerify = myConcern?.is_verify {
                vipImageView.isHidden = !isVerify
            }
            if let tips = myConcern?.tips {
                tipsButton.isHidden = !tips
            }
            if let userAuthInfo = myConcern!.userAuthInfo {
                vipImageView.image = userAuthInfo.auth_type == 1 ? UIImage(named: "all_v_avatar_star_16x16_") : UIImage(named: "all_v_avatar_18x18_")
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tipsButton.layer.borderWidth = 1
        tipsButton.layer.borderColor = UIColor.white.cgColor
    }

}
