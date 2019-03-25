//
//  AppDelegate.m
//  HSCharts
//
//  Created by _ | Durex on 16/6/23.
//  Copyright © 2016年 I really is a farmer. All rights reserved.
//

#import "AppDelegate.h"
#import "ListVC.h"
#import "GGGraphics.h"

#import "PieChart.h"
#import "GGPieLayer.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[UIViewController alloc]init];
    [self.window makeKeyAndVisible];
    
    UINavigationController * navi =  [[UINavigationController alloc] initWithRootViewController:[ListVC new]];
    [self.window setRootViewController:navi];
    
    //自定义返回按钮
    [[UIBarButtonItem appearance] setBackButtonBackgroundImage:[UIImage new]
                                                      forState:UIControlStateNormal
                                                    barMetrics:UIBarMetricsDefault];
    //将返回按钮的文字position设置不在屏幕上显示
    [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(-100, 0)
                                                         forBarMetrics:UIBarMetricsDefault];
    
    NSLog(@"%.2f", [UIScreen mainScreen].bounds.size.width);
    return YES;
}

@end
