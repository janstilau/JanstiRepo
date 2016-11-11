//
//  AppDelegate.m
//  wxLoginTesxt
//
//  Created by justin lau on 16/5/1.
//  Copyright © 2016年 justin lau. All rights reserved.
//

#import "AppDelegate.h"
#import "WXApi.h"


#define  kAppKey @"wxe63a6af33be57b5d"
#define  kAppSecret @"bc88d2d1352bff72c3c3e66628c2f89d"




@interface AppDelegate ()<WXApiDelegate>

@end

@implementation AppDelegate



- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if([url.absoluteString hasPrefix:@"wx"]) {
        
        
        
        return [WXApi handleOpenURL:url delegate:self.window.rootViewController];  //微信登陆
    }
       return NO;
}



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [WXApi registerApp:kAppKey];
    NSLog(@"%d",[WXApi isWXAppSupportApi]);
    NSLog(@"%d",[WXApi isWXAppInstalled]);
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
