//
//  MineViewController.swift
//  NewsDemo
//
//  Created by JustinLau on 2020/5/4.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON

class MineViewController: UIViewController {
    
    
    var tableView: UITableView?
    var sections = [[MyCellModel]]()
    var concerns = [MyConcern]()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.lightGray
        setupViews()
        requestData()
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

extension MineViewController {
    func requestData() {
        let url = BASE_URL + "/user/tab/tabs/?"
        let params = [
            "devece_id": kDeviceId
        ]
        Alamofire.request(url, parameters: params).responseJSON { (response) in
            guard response.result.isSuccess else {
                print("网络请求失败")
                return
            }
            if let value = response.result.value {
                let json = JSON(value)
                guard json["message"] == "success" else {
                    return
                }
                if let data = json["data"].dictionary,
                    let sections = data["sections"]?.array {
                    var sectionArray = [AnyObject]()
                    for item in sections {
                        var rows = [MyCellModel]()
                        for row in item.arrayObject! {
                            let myCellModel = MyCellModel.deserialize(from: row as? NSDictionary)
                            rows.append(myCellModel!)
                        }
                        sectionArray.append(rows as AnyObject)
                    }
                }
            }
        }
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


/*
 {
   "data" : {
     "sections" : [
       [
         {
           "icons" : {
             "day" : {
               "height" : 24,
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0660002e8c1d26332ce~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "uri" : ""
             },
             "night" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0660002e8c1d26332ce~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "mall",
           "url" : "sslocal:\/\/webview?url=https%3a%2f%2fis.snssdk.com%2ffeoffline%2fwallet_portal%2findex.html&title=%E6%88%91%E7%9A%84%E9%92%B1%E5%8C%85&hide_more=1&hide_bar=1&bounce_disable=1&hide_status_bar=1&back_button_color=white&status_bar_color=white&background_colorkey=3&should_append_common_param=1&disable_web_progressView=1&use_offline=1&show_load_anim=0",
           "text" : "钱包",
           "tip_new" : 0
         },
         {
           "icons" : {
             "day" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0740002e78806e1f2b3~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             },
             "night" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0740002e78806e1f2b3~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "msg_notification",
           "url" : "sslocal:\/\/message",
           "text" : "消息通知",
           "tip_new" : 0
         }
       ],
       [
         {
           "icons" : {
             "day" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0710002e60645fdecad~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             },
             "night" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0710002e60645fdecad~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "free_flow_service",
           "url" : "sslocal:\/\/webview?url=https%3a%2f%2fi.snssdk.com%2factivity%2fcarrier_flow%2fredirect%2f%3f&bounce_disable=1&title=%E5%85%8D%E6%B5%81%E9%87%8F%E6%9C%8D%E5%8A%A1",
           "text" : "免流量服务",
           "tip_new" : 0
         },
         {
           "icons" : {
             "day" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0700002e5835e8795dc~noop.webp"
                 }
               ],
               "width" : 24,
               "radius" : 0,
               "height" : 24
             },
             "night" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e0700002e5835e8795dc~noop.webp"
                 }
               ],
               "width" : 24,
               "height" : 24,
               "radius" : 0
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "ads_serving",
           "url" : "sslocal:\/\/webview?url=https%3a%2f%2flite.snssdk.com%2fself_service%2fapi%2fv1%2fpages%2flogin%3f%24from%3d1%26hide_bar%3d0%26bounce_disable%3d1",
           "text" : "广告推广",
           "tip_new" : 0
         }
       ],
       [
         {
           "icons" : {
             "day" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e06a0002e9c41f5391b4~noop.webp"
                 }
               ],
               "width" : 24,
               "height" : 24,
               "radius" : 0
             },
             "night" : {
               "uri" : "",
               "url_list" : [
                 {
                   "url" : "http:\/\/sf1-ttcdn-tos.pstatp.com\/img\/mosaic-legacy\/1e06a0002e9c41f5391b4~noop.webp"
                 }
               ],
               "width" : 24,
               "height" : 24,
               "radius" : 0
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "feedback",
           "url" : "sslocal:\/\/webview?url=https%3A%2F%2Fi.snssdk.com%2Ffeedback%2Farticle_news%2Fquestion_list%2F&hide_more=1&bounce_disable=1&hide_bar=1&hide_back_close=1&hide_close_btn=1&should_append_common_param=1&use_bd=1",
           "text" : "用户反馈",
           "tip_new" : 0
         },
         {
           "icons" : {
             "day" : {
               "uri" : "origin\/6649\/8382300936",
               "url_list" : [
                 {
                   "url" : "http:\/\/p1.pstatp.com\/origin\/6649\/8382300936"
                 },
                 {
                   "url" : "http:\/\/pb3.pstatp.com\/origin\/6649\/8382300936"
                 },
                 {
                   "url" : "http:\/\/pb3.pstatp.com\/origin\/6649\/8382300936"
                 }
               ],
               "width" : 24,
               "height" : 24
             },
             "night" : {
               "url_list" : [
                 {
                   "url" : "http:\/\/p1.pstatp.com\/origin\/6653\/7036384588"
                 },
                 {
                   "url" : "http:\/\/pb3.pstatp.com\/origin\/6653\/7036384588"
                 },
                 {
                   "url" : "http:\/\/pb3.pstatp.com\/origin\/6653\/7036384588"
                 }
               ],
               "width" : 24,
               "uri" : "origin\/6653\/7036384588",
               "height" : 24
             }
           },
           "tip_text" : "",
           "grey_text" : "",
           "key" : "config",
           "url" : "sslocal:\/\/more",
           "text" : "系统设置",
           "tip_new" : 0
         }
       ]
     ]
   },
   "message" : "success"
 }
 */
