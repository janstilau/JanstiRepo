

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
    // 几个例子都不是太好, 应该是专门有一个 Service 类, 来进行相关的 vc 的创建, 服务的调用. 直接把 VC 当做 Service 的实现者, 有点问题.
    id<HomeServiceProtocol> homeVc = [[BeeHive shareInstance] createService:@protocol(HomeServiceProtocol)];
    if ([homeVc isKindOfClass:[UIViewController class]]) {
        UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:(UIViewController*)homeVc];
        
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.rootViewController = navCtrl;
        
        [self.window makeKeyAndVisible];
    }
    
    return YES;
}


@end
