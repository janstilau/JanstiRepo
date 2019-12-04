//
//  MoodsTableViewController.swift
//  Moody
//
//  Created by Florian on 07/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import CoreData

// 由于 SeguePerformer 协议, 使得 segueIdentifier 这个函数自动可以适配到新的类.
// 将具体的功能, 按照协议进行拆分. 将相关的逻辑放到了一起. 问题在于, 这个类变得复杂了.

class MoodsTableViewController: UITableViewController, SeguePerformer, ManageContextContainer {

    enum SegueIdentifier: String {
        case showMoodDetail = "showMoodDetail"
    }

    var managedObjectContext: NSManagedObjectContext!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(for: segue) {
        case .showMoodDetail:
            guard let vc = segue.destination as? MoodDetailViewController else { fatalError("Wrong view controller type") }
            guard let mood = dataSource.selectedObject else { fatalError("Showing detail, but no selected row?") }
            vc.mood = mood
        }
    }


    // MARK: Private

    fileprivate var dataSource: TableViewDataSource<MoodsTableViewController>!
    fileprivate var observer: ManagedObjectObserver?

    fileprivate func setupTableView() {
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100
        let request = Mood.sortedFetchRequest
        request.fetchBatchSize = 20
        request.returnsObjectsAsFaults = false
        let featchVC = NSFetchedResultsController(fetchRequest: request,
                                                  managedObjectContext: managedObjectContext,
                                                  sectionNameKeyPath: nil,
                                                  cacheName: nil)
        // TableView 的真正的逻辑, 被封装到了 TableViewDataSource 这个类的内部了. 上面的操作, 都是在构造这个类的初始化参数.
        dataSource = TableViewDataSource(tableView: tableView, cellIdentifier: "MoodCell", fetchedResultsController: featchVC, delegate: self)
    }

}


extension MoodsTableViewController: TableViewDataSourceDelegate {
    func configure(_ cell: MoodTableViewCell, for object: Mood) {
        cell.configure(for: object)
    }
}


