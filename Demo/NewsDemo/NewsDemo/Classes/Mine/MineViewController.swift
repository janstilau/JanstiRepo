//
//  MineViewController.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit

class MineViewController: UIViewController {
    
    
    var tableView: UITableView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.lightGray
        setupViews()
    }
    
    func setupViews() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView?.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView?.backgroundColor = UIColor.globalBGColor()
        tableView?.tableFooterView = UIView()
        tableView?.disableAdjustBehavior()
        tableView?.disableEstimateHeight()
        view.addSubview(tableView!)
    }

}

/*
 因为 Swfit 里面权限控制的比较好, 这里其实可以在 extension 里面, 获取到类中定义的各个属性.
 通过 Extension 来进行代码的分块, 要比 OC 里面方便的多了.
 OC 里面的分类, 更多的还是用来做类的功能的增强功能. 原因在于, OC 的分类, 只能获取到 H 文件里面定义的属性, 这样, 分类里面不能进行很多属性的修改操作.
 现在 Swift 的这种组织方式, 让代码更加清晰了.
 */

extension MineViewController : UITableViewDelegate, UITableViewDataSource{
    
    // Mark: Height
    
    static let kSetionHeaderHeight: CGFloat = 20
    static let kSetionFooterHeight: CGFloat = 10
    
    // 在这个时候, tableView 就是参数里面的值, 如果想要引用到对象里面的 tableView, 就要用 self.tableView 使用, 在使用的时候, IDE 会自动添加 ?, 可选链调用
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return MineViewController.kSetionHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return MineViewController.kSetionFooterHeight
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    // Mark: Number
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    // Mark: View
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let height = MineViewController.kSetionHeaderHeight
        let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: kScreenWidth, height: height))
        header.backgroundColor = UIColor.randomColor()
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let height = MineViewController.kSetionHeaderHeight
        let footer = UIView(frame: CGRect(x: 0.0, y: 0.0, width: kScreenWidth, height: height))
        footer.backgroundColor = UIColor.randomColor()
        return footer
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = "Text"
        return cell
    }
    
    
}
