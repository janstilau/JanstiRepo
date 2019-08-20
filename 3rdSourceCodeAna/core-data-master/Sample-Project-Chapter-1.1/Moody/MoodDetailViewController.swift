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

    /**
     Mood 设置为隐式解包, 因为这个类的设计就是必须要传入一个 Mood 值, 才能正常的使用.
     数据的修改, 进行通知, 然后 View 层根据这个通知, 进行相应的操作.
     这里, mood 的修改, 会让 observer 成为新的数据, 对新的 mood 进行监听操作, 而 observer 的内部, 会管理者监听的状态.
     
     没有办法在每次个函数的内部, 都进行防卫编程. 最后的是, 在某个点之后, 就可以认定数据是安全的了, 而不需要每次都进行检测了. 这种点, 可以称之为是栅栏函数.
     对于一个类来说, 这种栅栏函数, 最好就是构造函数. 构造函数之后, 就一定保证里面的数据是有效的.
     而 Mood, 作为整个类想要进行展示的最核心的数据, 其实是应该放在构造函数里面的. 这里, 因为是用 storyBoard 进行的初始化, 不能直接调用构造函数, 所以, 在生成了 DetailVC 之后, 进行了显式的 mood 的赋值操作. 那么, 在之后的代码里面, mood 一定是有值的, 否则直接崩溃. 这个时候, Mood进行隐式的解包, 就是可以接受的.
     */
    var mood: Mood! {
        didSet {
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

    /**
     删除操作, 影响的是数据, 而数据的更改, 再引起后面的操作.
     */
    @IBAction func deleteMood(_ sender: UIBarButtonItem) {
        mood.managedObjectContext?.performChanges {
            self.mood.managedObjectContext?.delete(self.mood)
        }
    }


    // MARK: Private
    /**
     所有的界面更新, 都在一个方法里面.
     */
    fileprivate func updateViews() {
        moodView?.colors = mood.colors
        navigationItem.title = mood.dateDescription
    }

}

/**
 这种写法, 只会让变量进行一次初始化操作, 它解决了一个很大的问题就是, OC 中, 很多变量的初始化操作, 要么要每次函数调用的过程中, 注入检测代码, 如果没有初始化就进行一个 init 方法的调用, 要么就是在 initialize 或者 load 方法里面进行初始化. 这里, 将每个变量的初始化和变量定义仅仅的包装到了一起.
 */
private let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.includesApproximationPhrase = true
    formatter.allowedUnits = [.minute, .hour, .weekday, .month, .year]
    formatter.maximumUnitCount = 1
    return formatter
}()

/**
 extension 什么时候使用呢, 要用到的时候. 这里, 在这个场景下, 需要 Mood 进行 dateDescription 的生成, 而这个生成过程, 没有成为该 VC 的一个方法, 而是作为了 Mood 的一个方法. 责任进行了分化.
 OC 里面的分类, 也应该是这样用, 不过习惯于把所有的代码都写到数据类的内部了. 这里应该向这里学习.
 */
extension Mood {
    fileprivate var dateDescription: String {
        guard let timeString = dateComponentsFormatter.string(from: abs(date.timeIntervalSinceNow)) else { return "" }
        return localized(.mood_dateComponentFormat, args: [timeString])
    }
}

