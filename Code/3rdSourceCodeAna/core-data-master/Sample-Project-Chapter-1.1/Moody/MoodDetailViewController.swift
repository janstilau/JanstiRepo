//
//  MoodDetailViewController.swift
//  Moody
//
//  Created by Daniel Eggert on 15/05/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import MapKit


class MoodDetailViewController: UIViewController {

    @IBOutlet weak var moodView: MoodView!

    fileprivate var observer: ManagedObjectObserver?

    var mood: Mood! {
        didSet {
            // 生成一个 observer, 在 Mood 改变之后重新设置. 传入一个闭包, 在 ManagedObjectObserver 的内部, 监听 context 的变化, 然后执行闭包.
            observer = ManagedObjectObserver(object: mood) { [weak self] type in
                guard type == .delete else { return }
                _ = self?.navigationController?.popViewController(animated: true)
            }
            updateViews()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
    }

    @IBAction func deleteMood(_ sender: UIBarButtonItem) {
        // 先删除, 后 save.
        mood.managedObjectContext?.performChanges {
            self.mood.managedObjectContext?.delete(self.mood)
        }
    }


    // MARK: Private
    fileprivate func updateViews() {
        moodView?.colors = mood.colors // 更新内容视图
        navigationItem.title = mood.dateDescription
    }

}

// 类似于 static 的一个变量, 运用 block() 这种方式, 将 OC 需要判断 nil 然后进行初始化的尴尬写法, 进行了化解.
private let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.includesApproximationPhrase = true
    formatter.allowedUnits = [.minute, .hour, .weekday, .month, .year]
    formatter.maximumUnitCount = 1
    return formatter
}()

// 由于, dateDescription 仅仅会在这个类里面进行使用, 所以, Mood 的 dateDescription extension 写在了这里.
extension Mood {
    fileprivate var dateDescription: String {
        guard let timeString = dateComponentsFormatter.string(from: abs(date.timeIntervalSinceNow)) else { return "" }
        return localized(.mood_dateComponentFormat, args: [timeString])
    }
}

