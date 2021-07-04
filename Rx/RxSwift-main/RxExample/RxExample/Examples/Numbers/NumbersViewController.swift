//
//  NumbersViewController.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class NumbersViewController: ViewController {
    @IBOutlet weak var number1: UITextField!
    @IBOutlet weak var number2: UITextField!
    @IBOutlet weak var number3: UITextField!

    @IBOutlet weak var result: UILabel!
    @IBOutlet weak var ActionBtn: UIButton!
    
    var numbser = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
            当进入到 Rx 的世界的时候, 各种原有的 UIKit 的属性, 都是需要 Rx 的作者, 去做出相应的包装的.
            也就是说, 相对应的属性值, 已经不能当做原始属性那样直接拿来进行使用了, 而是必须在 RX 响应式的世界里面, 当做其中的一个节点.
         */
        Observable.combineLatest(number1.rx.text.orEmpty,
                                 number2.rx.text.orEmpty,
                                 number3.rx.text.orEmpty) {
            textValue1, textValue2, textValue3 -> Int in
                return (Int(textValue1) ?? 0) + (Int(textValue2) ?? 0) + (Int(textValue3) ?? 0)
            }
            .map { $0.description }
            .bind(to: result.rx.text) // Bind 就是将 Publisher 的信号, 发送给 Observer, 其实就是 Subscribe
            .disposed(by: disposeBag)
        
        
        number1.rx.text.orEmpty.subscribe { event in
            print("1 + \(event) ")
        }
        .disposed(by: disposeBag)
        
        number1.rx.text.orEmpty.subscribe { event in
            print("2 + \(event) ")
        }
        .disposed(by: disposeBag)
        
        number1.rx.text.orEmpty.subscribe { event in
            print("3 + \(event) ")
        }
        .disposed(by: disposeBag)
        
        number1.rx.text.orEmpty.subscribe { event in
            print("4 + \(event) ")
        }
        .disposed(by: disposeBag)
        // 在每次调用了 rx.text 之后, UITextField 的 AllTarget 的数量, 就会增加一份.
        
        let customProperty = ActionBtn.rx.controlProperty(editingEvents: UIControl.Event.touchUpInside) { btn in
            btn.title(for: .normal)
        } setter: { _, _ in
            print("Btn should set title")
        }
        print(customProperty)
         
        customProperty.orEmpty
        .subscribe { event in
            print(event)
            self.ActionBtn.setTitle("\(self.numbser)", for: .normal)
            self.numbser += 1
        }
        .disposed(by: disposeBag)
        
        
        
        // 从这里可以看出, 使用类.actionName 这种方式, 生成的 SEL 和直接使用方法名生成的 SEL 没有任何的区别.
        // 原因在于, SEL 本身就是一个方法字符串名的封装而已, 不是一个引用值.
        let leftAction = #selector(btnDidCliced(_:))
        let rightAction = #selector(NumbersViewController.btnDidCliced(_:))
        print(leftAction)
        print(rightAction)
        print(leftAction == rightAction)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        btnDidCliced(NSObject())
    }
    
    @objc func btnDidCliced(_ sender: NSObject) {
        let publisher = Observable<String>.create { observer in
            observer.onNext("1")
            observer.onNext("2")
            observer.onCompleted()
            return Disposables.create()
        }
        let sharePublisher = publisher.share()
        sharePublisher.subscribe { event in
            print("1")
            print(event)
        }
        sharePublisher.subscribe { event in
            print("2")
            print(event)
        }
        
    }
}
