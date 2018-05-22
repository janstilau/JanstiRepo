//
//  USNavDelegateHandler.h
//  USNavAnimation
//
//  Created by marujun on 15/12/26.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface USNavDelegateHandler : UIView <UINavigationControllerDelegate,UIGestureRecognizerDelegate>

@property (strong, nonatomic) UINavigationController *navigationController;

@end

@interface UINavigationController (USNavDelegateHandler)

@property (nonatomic, copy) void(^delegateCompletionHandler)();

/* TODO: 如果要使用下面这些扩展方法，UINavigationController的delegate必须是USNavDelegateHandler对象！！！
 */
- (UIViewController *)popViewControllerAnimated:(BOOL)animated completion:(void (^)())completion;

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated completion:(void (^)())completion;

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void (^)())completion;

@end
