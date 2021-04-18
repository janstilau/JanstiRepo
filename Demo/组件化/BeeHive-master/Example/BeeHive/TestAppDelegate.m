

//  TestAppDelegate.m
//  BeeHive
//
//  Created by 一渡 on 07/10/2015.
//  Copyright (c) 2015 一渡. All rights reserved.
//

#import "TestAppDelegate.h"
#import "BeeHive.h"
#import "BHService.h"
#import "BHTimeProfiler.h"
#import <mach-o/dyld.h>
#import "BHModuleManager.h"
#import "BHServiceManager.h"

@interface TestAppDelegate ()

@end

@implementation TestAppDelegate

@synthesize window;

// AppDelegate, 主要作用, 其实是接受 Application 的各个事件. 所以, 它能够响应到各个事件的通知就可以了.
// 在主工程里面, 做一些全局数据的配置工作.

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [BHContext shareInstance].application = application;
    [BHContext shareInstance].launchOptions = launchOptions;
    [BHContext shareInstance].moduleConfigName = @"BeeHive.bundle/BeeHive";//可选，默认为BeeHive.bundle/BeeHive.plist
    [BHContext shareInstance].serviceConfigName = @"BeeHive.bundle/BHService";
    
    [BeeHive shareInstance].enableException = YES;
    [[BeeHive shareInstance] setContext:[BHContext shareInstance]];
    [[BHTimeProfiler sharedTimeProfiler] recordEventTime:@"BeeHive::super start launch"];

    
    [super application:application didFinishLaunchingWithOptions:launchOptions];
    

    // 这里, 直接是使用了 [BeeHive shareInstance] 的 createService 来进行了相关 vc 的创建工作.
    // 主工程, 完全是一个壳, 就连 main VC 的获取, 都是通过 Module 获取的.
    id<HomeServiceProtocol> homeVc = [[BeeHive shareInstance] createService:@protocol(HomeServiceProtocol)];
    if ([homeVc isKindOfClass:[UIViewController class]]) {
        // 主 Application, 所承担的, 仅仅是获取到 VC, 然后设置到 window 上而已.
        // 主工程, 根本不知道业务的各种信息.
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:(UIViewController*)homeVc];
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.rootViewController = navCtrl;
        
        [self.window makeKeyAndVisible];
    }
    
    return YES;
}


@end
