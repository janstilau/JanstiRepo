#import "UIViewController.h"

@class UITabBarController;
@protocol UITabBarControllerDelegate <NSObject>

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController;
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
- (void)tabBarController:(UITabBarController *)tabBarController willBeginCustomizingViewControllers:(NSArray *)viewControllers;
- (void)tabBarController:(UITabBarController *)tabBarController willEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed;

@end

@class UITabBar;
@interface UITabBarController : UIViewController
- (void)setViewControllers:(NSArray *)viewController animated:(BOOL)animated;

@property (nonatomic, assign) UIViewController *selectedViewController;
@property (nonatomic, copy)   NSArray *viewControllers;
@property (nonatomic, assign) NSUInteger selectedIndex;
@property (nonatomic, readonly) UITabBar *tabBar;
@end
