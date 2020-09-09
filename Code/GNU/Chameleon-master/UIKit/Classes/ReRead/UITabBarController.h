#import "UIViewController.h"

@class UITabBarController;
@protocol UITabBarControllerDelegate <NSObject>

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController;
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
- (void)tabBarController:(UITabBarController *)tabBarController willBeginCustomizingViewControllers:(NSArray *)viewControllers;
- (void)tabBarController:(UITabBarController *)tabBarController willEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed;

@end

/*
 作者没有实现这个类, 不过 MC 的很多 rootVC 都是自定义的 TabBarViewController. 基本思路就是, tabBar 的 button 被点击之后, 更换自己展示的内容为相应的 subVC 的 view.
 */

@class UITabBar;
@interface UITabBarController : UIViewController
- (void)setViewControllers:(NSArray *)viewController animated:(BOOL)animated;

@property (nonatomic, assign) UIViewController *selectedViewController;
@property (nonatomic, copy)   NSArray *viewControllers;
@property (nonatomic, assign) NSUInteger selectedIndex;
@property (nonatomic, readonly) UITabBar *tabBar;
@end
