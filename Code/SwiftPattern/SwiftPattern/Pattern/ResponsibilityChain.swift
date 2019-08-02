
//
//  ResponsibilityChain.swift
//  SwiftPattern
//
//  Created by JustinLau on 2019/8/2.
//  Copyright © 2019 JustinLau. All rights reserved.
//

import Foundation

/**
 使得多个对象都有机会处理请求, 从而避免了请求的发送者和接受者之间的耦合关系, 将这个对象构成一条链, 并且沿着这个链进行请求的传递, 知道有一个对象处理它为止.
 
 handler 的 handle 函数一般是这样的一个逻辑, 判断 request 自己可不可以进行处理, 如果可以处理, 就调用自己的 process 函数. 否则的话, 将 request 对象原封不动的传递到自己的 nextHandler 中, 直到request被处理, 或者链条结束.

enum RequestType {
    RequestType_1,
    RequestType_2,
    RequestType_3
};

class Request {
    private:
    string mDescription;
    RequestType mReqType;
    public:
    Request(const string& desc, RequestType type):
    mDescription(desc), mReqType(type){    };
    RequestType getType() const { return mReqType; }
    const string& getDesc() const { return mDescription; }
};

class ChainHandler {
    private:
    ChainHandler *mNext;
    void sendRequestToNext(const Request &req) {
        if (mNext != nullptr) {
        mNext->processReq(req);
    }
    }
    protected:
    virtual bool candHandleReq(const Request& req) = 0;
    virtual void processReq(const Request& req) = 0;
    public:
    ChainHandler() { mNext = nullptr; }
    void setNextHandler(ChainHandler *next) { mNext = next; }
    
    void handler(const Request &req) {
    if (candHandleReq(req)) {
        processReq(req);
    } else {
        sendRequestToNext(req);
    }
    }
};
*/

protocol WithDrawing {
    func canWithDraw(amount: Int) -> Bool
    func withDraw(amount: Int)
}

final class MoneyPile: WithDrawing {
    
    let value: Int
    var quanity: Int
    var next: WithDrawing?
    
    init(value: Int, quantity: Int, next: WithDrawing?) {
        self.value = value
        self.quanity = quantity
        self.next = next
    }
    
    func canWithDraw(amount: Int) -> Bool {
        if (amount < 0) {
            return false
        }
        if (quanity <= 0) {
            return false
        }
        let number = amount / self.value
        if (quanity < number) {
            return false
        }
        
        var amount = amount
        amount -= number * value
        guard amount > 0 else {
            return true
        }
        if let next = self.next {
            return next.canWithDraw(amount: amount)
        }
        return false
    }
    
    func withDraw(amount: Int) {
        let number = amount / value
        quanity -= number
        let amount = amount - number * value
        if let next = self.next {
            next.withDraw(amount: amount)
        }
    }
}

func ChainDemo() {
    let OnePile = MoneyPile(value: 1, quantity: 3, next: nil)
    let FivePile = MoneyPile(value: 5, quantity: 4, next: OnePile)
    let TenPile = MoneyPile(value: 10, quantity: 8, next: FivePile)
    let TwentyPile = MoneyPile(value: 20, quantity: 2, next: TenPile)
    let FiftyPile = MoneyPile(value: 50, quantity: 3, next: TwentyPile)
    let HundredPile = MoneyPile(value: 100, quantity: 1, next: FiftyPile)
    
    let moneyArray = [123, 312, 23, 33, 44, 55, 98]
    for money in moneyArray {
        if HundredPile.canWithDraw(amount: money) {
             print("The money \(money) can be handle")
        } else {
             print("The money \(money) should handle to next bank")
        }
       
    }
}
