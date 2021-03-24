//
//  Target_A.h
//  CTMediator
//
//  Created by casa on 16/3/13.
//  Copyright © 2016年 casa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 专门的一个业务模块, 来处理 target 指向是 A 的请求.
/*
 如果是 VIP 相关的请求, 其实, 就是 Vip 模块的编写者, 应该编写 Target_Vip 这个类, 用作处理外界请求的统一的入口.
 同时, 应该编写 CTMediator + VIP 的分类,
 在分类里面包装 Target 为 "Vip", Action 为  "nativeFetchDetailViewController", 为外界提供更加方法的处理方法.
 
 CTMediator 里面, 仅仅是做最终方法调用的分发处理. 如果, Target 没有生成, 就生成对应的 Target 并且缓存起来.
 并且, 拼接出 SEL, 以及各个参数出来, 然后调用生成的 Target 的各个方法.
 
 类名, 固定为 Target 开头, 方法名, 固定位 Action 开头, 证明这个类是一个 Service, 它的方法, 是一个 Service 的方法.
 这个类内部, 应该固定的使用 NSDictionary 作为参数, 这样可以处理多参数, 也可以方便之后的扩展.
 因为 CTMediator + VIP 这个分类, 其实也是维护 Target_Vip 的人维护的, 所以, 这里根据字符串 key 去 params 取值, 是可控的.
 
 在这个类里面, 也可以写 notFound 方法, 进行无效的 SEL 的处理.
 */

@interface Target_A : NSObject

- (UIViewController *)Action_nativeFetchDetailViewController:(NSDictionary *)params;
- (id)Action_nativePresentImage:(NSDictionary *)params;
- (id)Action_showAlert:(NSDictionary *)params;

// 容错
- (id)Action_nativeNoImage:(NSDictionary *)params;

@end
