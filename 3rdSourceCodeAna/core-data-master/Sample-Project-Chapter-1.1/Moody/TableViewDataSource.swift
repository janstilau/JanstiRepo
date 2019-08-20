//
//  TableViewDataSource.swift
//  Moody
//
//  Created by Florian on 31/08/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import UIKit
import CoreData


protocol TableViewDataSourceDelegate: class {
    associatedtype Object: NSFetchRequestResult
    associatedtype Cell: UITableViewCell
    func configure(_ cell: Cell, for object: Object)
}


/// Note: this class doesn't support working with multiple sections
/**
 dataSource 从, TableView 中进行了脱离.
 TableViewDataSource 处理的都是和数据源相关的方法, 但是数据源里面cell 如何显示, 是变化的, 所以, TableViewDataSourceDelegate 这个协议就是讲 cell 的显示工作, 转移到了外部. 因为 cell 的显示, 也是 tableView 中最为重要的一部分
 */
class TableViewDataSource<Delegate: TableViewDataSourceDelegate>: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    // 这两个仅仅是重命名而已. 它确定了 tableViewDataSource 中操作的数据, 和这个类中操作的数据, 类型是一致的.
    typealias ManageObject = Delegate.Object
    typealias ShowCell = Delegate.Cell

    required init(tableView: UITableView, cellIdentifier: String, fetchedResultsController: NSFetchedResultsController<ManageObject>, delegate: Delegate) {
        self.tableView = tableView
        self.cellIdentifier = cellIdentifier
        self.fetchedResultsController = fetchedResultsController
        self.delegate = delegate
        super.init()
        fetchedResultsController.delegate = self
        try! fetchedResultsController.performFetch() // 真正的 fetch 操作发生在此时.
        tableView.dataSource = self
        tableView.reloadData()
    }

    var selectedObject: ManageObject? {
        guard let indexPath = tableView.indexPathForSelectedRow else { return nil }
        return objectAtIndexPath(indexPath)
    }

    func objectAtIndexPath(_ indexPath: IndexPath) -> ManageObject {
        return fetchedResultsController.object(at: indexPath)
    }

    func reconfigureFetchRequest(_ configure: (NSFetchRequest<ManageObject>) -> ()) {
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: fetchedResultsController.cacheName)
        configure(fetchedResultsController.fetchRequest)
        do { try fetchedResultsController.performFetch() } catch { fatalError("fetch request failed") }
        tableView.reloadData()
    }


    // MARK: Private

    fileprivate let tableView: UITableView
    fileprivate let fetchedResultsController: NSFetchedResultsController<ManageObject>
    fileprivate weak var delegate: Delegate! // 必须要有这个属性. 但是这个属性又不能在 init 方法里面直接指定.
    fileprivate let cellIdentifier: String

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = fetchedResultsController.sections?[section] else { return 0 }
        return section.numberOfObjects
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = fetchedResultsController.object(at: indexPath)
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ShowCell
        else {
            fatalError("Unexpected cell type at \(indexPath)")
        }
        delegate.configure(cell, for: object)
        return cell
    }

    // MARK: NSFetchedResultsControllerDelegate

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let indexPath = newIndexPath else { fatalError("Index path should be not nil") }
            tableView.insertRows(at: [indexPath], with: .fade)
        case .update:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            let object = objectAtIndexPath(indexPath)
            guard let cell = tableView.cellForRow(at: indexPath) as? ShowCell else { break }
            delegate.configure(cell, for: object)
        case .move:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            guard let newIndexPath = newIndexPath else { fatalError("New index path should be not nil") }
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.insertRows(at: [newIndexPath], with: .fade)
        case .delete:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

