//
//  CTMediator+HandyTools.m
//  CTMediator
//
//  Created by casa on 2020/3/10.
//  Copyright © 2020 casa. All rights reserved.
//

#if TARGET_OS_IOS

#import "CTMediator+HandyTools.h"

// 简便的, 进行最外层 VC 获取, Push, Present 的快捷方法.

@implementation CTMediator (HandyTools)

- (UIViewController *)topViewController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    /*
     The view controller that is presented by this view controller, or one of its ancestors in the view controller hierarchy.
     When you present a view controller modally (either explicitly or implicitly) using the present(_:animated:completion:) method, the view controller that called the method has this property set to the view controller that it presented. If the current view controller did not present another view controller modally, the value in this property is nil.
     */
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // 寻找最顶层的 NavigationVC, 然后 push.
    UINavigationController *navigationController = (UINavigationController *)[self topViewController];
    
    if ([navigationController isKindOfClass:[UINavigationController class]] == NO) {
        if ([navigationController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tabbarController = (UITabBarController *)navigationController;
            navigationController = tabbarController.selectedViewController;
            if ([navigationController isKindOfClass:[UINavigationController class]] == NO) {
                navigationController = tabbarController.selectedViewController.navigationController;
            }
        } else {
            navigationController = navigationController.navigationController;
        }
    }
    
    if ([navigationController isKindOfClass:[UINavigationController class]]) {
        [navigationController pushViewController:viewController animated:animated];
    }
}

// 找到最顶层的 VC, 然后 present 对应的 VC 出来.
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)animated completion:(void (^ _Nullable)(void))completion
{
    UIViewController *viewController = [self topViewController];
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)viewController;
        viewController = navigationController.topViewController;
    }
    
    if ([viewController isKindOfClass:[UIAlertController class]]) {
        /*
         presentingViewController
         The view controller that presented this view controller.
         When you present a view controller modally (either explicitly or implicitly) using the present(_:animated:completion:) method, the view controller that was presented has this property set to the view controller that presented it. If the view controller was not presented modally, but one of its ancestors was, this property contains the view controller that presented the ancestor. If neither the current view controller or any of its ancestors were presented modally, the value in this property is nil.
         */
        UIViewController *viewControllerToUse = viewController.presentingViewController;
        [viewController dismissViewControllerAnimated:false completion:nil];
        viewController = viewControllerToUse;
    }
    
    if (viewController) {
        [viewController presentViewController:viewControllerToPresent animated:animated completion:completion];
    }
}

@end

#endif
