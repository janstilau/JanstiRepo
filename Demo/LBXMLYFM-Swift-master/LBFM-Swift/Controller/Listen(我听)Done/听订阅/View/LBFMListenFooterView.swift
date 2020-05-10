//
//  LBFMListenFooterView.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/2/25.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit

/// 添加按钮点击代理方法
protocol LBFMListenFooterViewDelegate:NSObjectProtocol {
    func listenFooterAddBtnClick()
}

/// 订阅和一键听底部添加按钮
class LBFMListenFooterView: UIView {
    
    weak var delegate : LBFMListenFooterViewDelegate?
    
    private var centerBtn: UIButton = {
        let button = UIButton.init(type: UIButton.ButtonType.custom)
        button.setTitleColor(UIColor.black, for: UIControl.State.normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.backgroundColor = UIColor.white
        button.addTarget(self, action: #selector(addButtonClick), for: UIControl.Event.touchUpInside)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 20
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setUpLayout(){
        self.addSubview(centerBtn)
        centerBtn.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(40)
            make.width.equalTo(120)
            make.centerX.equalToSuperview()
        }
    }
    
    // DidSet 里面, 做 UI 的处理工作
    var listenFooterViewTitle:String?{
        didSet {
            centerBtn.setTitle(listenFooterViewTitle, for: UIControl.State.normal)
        }
    }
    
    @objc func addButtonClick(){
        delegate?.listenFooterAddBtnClick()
    }
}
