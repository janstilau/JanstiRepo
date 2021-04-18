/**
 * Created by BeeHive.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the GNU GENERAL PUBLIC LICENSE.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import "BHModuleProtocol.h"
#import "BHContext.h"
#import "BHAppDelegate.h"
#import "BHModuleManager.h"
#import "BHServiceManager.h"

@interface BeeHive : NSObject

/*
 简单的 Service 的注册, 可以使用 CAMediator 的形式.
 但是很多时候, 我们是想要接受 Application 的生命周期管理的, 比方说, Socket 需要接受前后台的切换事件, 做一些资源的释放或者重新加载.
 这件事情, 可以通过 Notification 来获得监听. 但是这样过于分撒, 但如果把所有的事情, 都写在 Appdelegate 里面, 那么所有的模块, 都要和 Appledegate 有依赖了.
 这个框架, 比 CAMediator 更多的部分, 就是有了这一层 Module 的管理.
 各个 Module, 专门定义自己的 Manager, 然后将这个 Manager 注册到 MudleManager 里面, 就可以接收到各种事件的分发了.
 Service 的注册, 也应该写到这个 Module 对于特定事件的处理上. 这样, 所有关于组件化通信的东西, 集中到一点.
 这比各个 Module 在自己的业务类里面, 去监听各个 Notification 要清晰地多了
 */

@property(nonatomic, strong) BHContext *context;

@property (nonatomic, assign) BOOL enableException;

+ (instancetype)shareInstance;

+ (void)registerDynamicModule:(Class) moduleClass;

- (id)createService:(Protocol *)proto;

//Registration is recommended to use a static way
- (void)registerService:(Protocol *)proto service:(Class) serviceClass;

+ (void)triggerCustomEvent:(NSInteger)eventType;
    
@end
