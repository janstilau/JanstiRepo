//
//  LBFMFindController.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/2/1.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit
import LTScrollView

class LBFMFindController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        self.automaticallyAdjustsScrollViewInsets = false
        view.addSubview(advancedManager)
        advancedManagerConfig()
        setupNavBarBtns()
    }
    
    /* Private, 只能在当前的作用域块里面使用.
     Swift 没有 h,m 的区分, 但是, 自由度大的访问控制权限的设置, 使得代码也能很好的进行组织.
     LBFMFindHeaderView 作为头部, 将数据的获取和展示都封装到了内容, 没有问题.
     */
    private lazy var headerView:LBFMFindHeaderView = {
        let view = LBFMFindHeaderView.init(frame: CGRect(x:0, y:0, width:LBFMScreenWidth, height:190))
        view.backgroundColor = UIColor.white
        return view
    }()
    
    // MARK:- ScrollRelated
    
    private lazy var advancedManager: LTAdvancedManager = {
        let statusBarH = UIApplication.shared.statusBarFrame.size.height
        let advancedManager = LTAdvancedManager(frame: CGRect(x: 0, y: LBFMNavBarHeight, width: LBFMScreenWidth, height: LBFMScreenHeight - LBFMNavBarHeight), viewControllers: viewControllers, titles: titles, currentViewController: self, layout: layout, headerViewHandle: {[weak self] in
            guard let strongSelf = self else { return UIView() }
            let headerView = strongSelf.headerView
            return headerView
        })
        /* 设置代理 监听滚动 */
        advancedManager.delegate = self
        /* 设置悬停位置 */
        // advancedManager.hoverY = navigationBarHeight
        /* 点击切换滚动过程动画 */
        // advancedManager.isClickScrollAnimation = true
        /* 代码设置滚动到第几个位置 */
        // advancedManager.scrollToIndex(index: viewControllers.count - 1)
        return advancedManager
    }()
    
    private lazy var layout: LTLayout = {
        let layout = LTLayout()
        layout.isAverage = true
        layout.sliderWidth = 80
        layout.titleViewBgColor = UIColor.white
        layout.titleColor = UIColor(r: 178, g: 178, b: 178)
        layout.titleSelectColor = UIColor(r: 16, g: 16, b: 16)
        layout.bottomLineColor = UIColor.red
        layout.sliderHeight = 56
        /* 更多属性设置请参考 LTLayout 中 public 属性说明 */
        return layout
    }()
    
    private lazy var viewControllers: [UIViewController] = {
        let findAttentionVC = LBFMFindAttentionController()
        let findRecommendVC = LBFMFindRecommendController()
        let findDuDYVC = LBFMFindDudController()
        return [findAttentionVC, findRecommendVC, findDuDYVC]
    }()
    
    private lazy var titles: [String] = {
        return ["关注动态", "推荐动态", "趣配音"]
    }()
    
    // MARK:- NavBar
    
    func setupNavBarBtns() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(customView: leftBarButton)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: rightBarButton)
    }
    
    private lazy var leftBarButton:UIButton = {
        let button = UIButton.init(type: UIButton.ButtonType.custom)
        button.frame = CGRect(x:0, y:0, width:30, height: 30)
        button.setImage(UIImage(named: "msg"), for: UIControl.State.normal)
        // Target-Action 模式太经典了, 不会因为一门语言的变化就修改的. 所以, Swift 的项目里面, 也要大量的使用.
        button.addTarget(self, action: #selector(leftBarButtonClick), for: UIControl.Event.touchUpInside)
        return button
    }()

    private lazy var rightBarButton:UIButton = {
        let button = UIButton.init(type: UIButton.ButtonType.custom)
        button.frame = CGRect(x:0, y:0, width:30, height: 30)
        button.setImage(UIImage(named: "搜索"), for: UIControl.State.normal)
        button.addTarget(self, action: #selector(rightBarButtonClick), for: UIControl.Event.touchUpInside)
        return button
    }()
    
    // @objc , 如果要用到 OC 里面 Runtime 相关的方法, 必须用这个进行标识.
    @objc func leftBarButtonClick() {
        print("leftBarButtonClick")
    }
    
    @objc func rightBarButtonClick() {
        print("rightBarButtonClick")
    }
}

// FineController 是一个控件的代理, 专用在一个 Extension 里面进行了表示, 这样代码比较分开.

extension LBFMFindController : LTAdvancedScrollViewDelegate {
    // 具体使用请参考以下
    private func advancedManagerConfig() {
        // 选中事件
        advancedManager.advancedDidSelectIndexHandle = {
            print("选中了 -> \($0)")
        }
    }
    
    func glt_scrollViewOffsetY(_ offsetY: CGFloat) {
        print("\(offsetY)")
    }
}

