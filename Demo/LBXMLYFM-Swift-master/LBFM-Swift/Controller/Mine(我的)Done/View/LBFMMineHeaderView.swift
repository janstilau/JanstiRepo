//
//  LBFMMineHeaderView.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/3/1.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit

/*
 Delegate shopBtnClick 的方法命名, 感觉不符合 OC 的标准, 是不是原来 OC 的命名标准在 Swift 里面不管用了.
 */
protocol LBFMMineHeaderViewDelegate:NSObjectProtocol {
    func shopBtnClick(tag:Int)
}

class LBFMMineHeaderView: UIView {
    /*
     Delegate 的写法, 和 OC 没有太大的不同.
     */
    weak var delegate : LBFMMineHeaderViewDelegate?

    private lazy var animationView:LBFMVipAnimationView = {
        let view = LBFMVipAnimationView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10
        view.addBorderLine()
        return view
    }()
    
    // 头像
    private lazy var imageView:UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "tom")
        return imageView
    }()
    
    // 昵称
    private lazy var nickName:UILabel = {
        let label = UILabel()
        label.text = "JCSON先生"
        return label
    }()
    
    // 粉丝
    private lazy var fansLabel:UILabel = {
        let label = UILabel()
        label.text = "粉丝  100万"
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()
    
    // 关注
    private lazy var attentionL:UILabel = {
        let label = UILabel()
        label.text = "关注  7"
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 15)
        return label
    }()
    
    // 解锁
    private lazy var clearLabel:UILabel = {
        let label = UILabel()
        label.text = "已听9分钟，满3小时解锁>"
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = NSTextAlignment.center
        label.layer.borderColor = UIColor.gray.cgColor
        label.layer.borderWidth = 0.5
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 13
        return label
    }()
    
    
    // shopView
    private lazy var shopView:UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        return view
    }()
    
    // shopView上细线
    private lazy var lineView:UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.init(r: 240, g: 240, b: 240)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLayout()
        setUpShopView()
        for aView in self.subviews {
            aView.addBorderLine()
        }
        self.backgroundColor = UIColor.white
    }
    
    func setUpLayout(){
        
        self.addSubview(self.animationView)
        self.animationView.snp.makeConstraints { (make) in
            make.width.equalTo(120)
            make.height.equalTo(80)
            make.top.equalTo(120)
            make.right.equalToSuperview().offset(-20)
        }
        // 在这里, 进行了旋转的工作.
        self.animationView.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 12)
        
        self.addSubview(self.imageView)
        self.imageView.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(80)
            make.width.height.equalTo(80)
        }
        
        self.addSubview(self.nickName)
        self.nickName.snp.makeConstraints { (make) in
            make.left.equalTo(self.imageView.snp.right).offset(10)
            make.top.equalTo(self.imageView.snp.top).offset(10)
            make.width.equalTo(100)
            make.height.equalTo(20)
        }
        
        self.addSubview(self.fansLabel)
        self.fansLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.nickName)
            make.bottom.equalTo(self.imageView.snp.bottom).offset(-10)
            make.width.equalTo(80)
            make.height.equalTo(20)
        }
        
        self.addSubview(self.attentionL)
        self.attentionL.snp.makeConstraints { (make) in
            make.left.equalTo(self.fansLabel.snp.right).offset(10)
            make.bottom.height.width.equalTo(self.fansLabel)
        }
        
        self.addSubview(self.clearLabel)
        /*
         这里的代码有问题, 这些值的配置, 为什么不在懒加载里面写到. setUpLayout 就应该做布局相关的工作.
         转移到 clearLabel 的懒加载中.
         */
//        self.clearLabel.layer.borderColor = UIColor.gray.cgColor
//        self.clearLabel.layer.borderWidth = 0.5
//        self.clearLabel.layer.masksToBounds = true
//        self.clearLabel.layer.cornerRadius = 13
        self.clearLabel.snp.makeConstraints { (make) in
            make.left.equalTo(self.imageView)
            make.bottom.equalToSuperview().offset(-110)
            make.height.equalTo(26)
            make.width.equalTo(220)
        }
        
        self.addSubview(self.shopView)
        self.shopView.snp.makeConstraints { (make) in
            make.right.left.bottom.equalToSuperview()
            make.height.equalTo(100)
        }
        
        self.shopView.addSubview(self.lineView)
        self.lineView.snp.makeConstraints { (make) in
            make.right.left.top.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
    }
    
    func setUpShopView(){
        let margin:CGFloat = LBFMScreenWidth / 10
        let titleArray = ["已购","优惠券","喜点","直播喜钻","我的钱包"]
        let dataArray = ["10","2","88","66","钱包"]
        for index in 0..<5 {
            let button = UIButton.init(frame: CGRect(x:margin*CGFloat(index)*2+margin/2,y:10,width:margin,height:margin))
            if index == 4 {
                button.setImage(UIImage(named: dataArray[index]), for: UIControl.State.normal)
            }else {
                button.setTitle(dataArray[index], for: UIControl.State.normal)
                button.setTitleColor(UIColor.black, for: UIControl.State.normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 25)
            }
            button.tag = index
            button.addTarget(self, action: #selector(gridBtnClick(button:)), for: UIControl.Event.touchUpInside)
            self.shopView.addSubview(button)
            
            let titleLabel = UILabel()
            titleLabel.textAlignment = .center
            titleLabel.text = titleArray[index]
            titleLabel.textColor = UIColor.gray
            titleLabel.font = UIFont.systemFont(ofSize: 15)
            self.addSubview(titleLabel)
            titleLabel.snp.makeConstraints({ (make) in
                make.centerX.equalTo(button)
                make.width.equalTo(margin+30)
                make.top.equalTo(button.snp.bottom).offset(10)
            })
        }
    }
    
    /*
     相比, OC 里面 delegate 非空判断之后, 方法实现判断. 这种方法显得更加的简洁.
     */
    @objc func gridBtnClick(button:UIButton){
           delegate?.shopBtnClick(tag: button.tag)
    }
    
    // 这里, 动画的起始和结束, 是受到外界控制的. 在 VC 里面, 根据 ViewDidAppear 和 DidDisApprear 进行的调用.
    // 开始动画, 就是用的最简单的 UIView 动画的封装.
    func setAnimationViewAnimation(){
        let yorig:CGFloat = 100.0 + 64
        let opts: UIView.AnimationOptions = [.autoreverse , .repeat]
        UIView.animate(withDuration: 1, delay: 1, options: opts, animations: {
            self.animationView.center.y -= 20
        }) { _ in
            self.animationView.center.y = yorig
        }
    }
    // 停止动画
    func stopAnimationViewAnimation(){
        self.animationView.layer.removeAllAnimations()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
