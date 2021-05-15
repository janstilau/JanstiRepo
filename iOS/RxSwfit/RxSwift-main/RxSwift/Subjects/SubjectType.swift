//
//  SubjectType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/1/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
 
 Subject 同时可以作为 Publisher 和 Observer.
 可以作为 Publisher, 是因为暴露了 Observer 的接口, Subject 提供了 API, 调用之后可以将数据添加到事件流中.
 所以, 各种 Subject 的 send 相关的调用, 就是在里面调用了 on 方法.
 
 Subject 作为事件流中的一环. 不同种类的 Subject, 提供了自己的业务功能的实现.
 */


/// Represents an object that is both an observable sequence as well as an observer.
public protocol SubjectType : ObservableType {
    /// The type of the observer that represents this subject.
    ///
    /// Usually this type is type of subject itself, but it doesn't have to be.
    associatedtype Observer: ObserverType

    /// Returns observer interface for subject.
    ///
    /// - returns: Observer interface for subject.
    func asObserver() -> Observer
    
}
