//
//  GSKVOBase.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 这是个操作集合类, 存放了 KVO 生成的子类需要重写的一些方法.
 为什么要有这样的一个类呢.
 KVO 铁定是要复写这个类里面的方法的, 但是, 怎么复写呢.
 KVO 是动态生成的, 是没有办法去知道哪个类需要生成 KVO 的子类的. 所有, 这个 GSKVOBase 中, 预先写好了要进行复写的方法, 然后利用方法的替换功能, 为新生成的类, 添加 KVO 想要替换的方法的实现.
 */
@interface    GSKVOBase : NSObject

@end

NS_ASSUME_NONNULL_END
