//
//  LBFMFindAttentionController.swift
//  LBFM-Swift
//
//  Created by liubo on 2019/2/28.
//  Copyright © 2019 刘博. All rights reserved.
//

import UIKit
import LTScrollView

class LBFMFindAttentionController: UIViewController , LTTableViewProtocal{
    
    /*
     Private let 的写法, 就是定义类内使用的私有常量的写法.
     */
    private let LBFMFindAttentionCellID = "LBFMFindAttentionCell"
    
    /*
     懒加载的大量使用. 使得初始化操作和属性的定义离得非常近.
     */
    private lazy var tableView: UITableView = {
        // 这个方法的定义就很差. 完全没有利用到函数名中 Label 的作用. self, self 一个是 delegate, 一个是 dataSource, 为什么完全没有体现出来.
        let tableView = tableViewConfig(CGRect(x: 0,
                                               y: 0,
                                               width:LBFMScreenWidth,
                                               height: LBFMScreenHeight - LBFMNavBarHeight - LBFMTabBarHeight),
                                        self, self, nil)
        tableView.register(LBFMFindAttentionCell.self, forCellReuseIdentifier: LBFMFindAttentionCellID)
        return tableView
    }()
    
    // 懒加载
    lazy var viewModel: LBFMFindAttentionViewModel = {
        return LBFMFindAttentionViewModel()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.view.addSubview(tableView) // 懒加载的大量使用. 使得业务代码里面, 几乎不再用 setup 了.
        glt_scrollView = tableView
        
        // 这里, 作者应该将下面的代码, 定义到 extension 里面的.
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        
        setupLoadData()
    }
    
    
    /*
     MVVM 的简单应用 ???
     */
    func setupLoadData() {
        // 定义 ViewModel 的回调, 然后 viewModel 内部进行数据的加载操作.
        viewModel.updataBlock = { [unowned self] in
            self.tableView.reloadData()
        }
        viewModel.refreshDataSource()
    }
    
}


/*
    Swfit 常见的代码结构, 用 Extension 进行代码块的区分.
    其实这是 Swift 的权限管理关键字的功劳.
    Internal 使得可以在任何的 Extension 里面访问属性.
    FilePridate 使得可以在文件内进行属性的访问.
    Privarte 进行真正的私有方法, 私有函数的定义.
    之前, Category 不能大量使用, 就是因为在其他的文件里面, 难以进行成员变量的修改.
 */
extension LBFMFindAttentionController : UITableViewDelegate, UITableViewDataSource {
    
    /*
     所有的修改, 都转移到了 ViewModel 的层面.
     */
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModel.heightForRowAt(indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:LBFMFindAttentionCell = tableView.dequeueReusableCell(withIdentifier: LBFMFindAttentionCellID, for: indexPath) as! LBFMFindAttentionCell
        cell.selectionStyle = UITableViewCell.SelectionStyle.none
        cell.eventInfosModel = viewModel.eventInfos?[indexPath.row]
        return cell
    }
}

