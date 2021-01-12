#import "UIView.h"

@class UITabBar, UITabBarItem;

@protocol UITabBarDelegate <NSObject>
@optional

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;

// stub
- (void)tabBar:(UITabBar *)tabBar willBeginCustomizingItems:(NSArray *)items;                     // called before customize sheet is shown. items is current item list
- (void)tabBar:(UITabBar *)tabBar didBeginCustomizingItems:(NSArray *)items;                      // called after customize sheet is shown. items is current item list
- (void)tabBar:(UITabBar *)tabBar willEndCustomizingItems:(NSArray *)items changed:(BOOL)changed; // called before customize sheet is hidden. items is new item list
- (void)tabBar:(UITabBar *)tabBar didEndCustomizingItems:(NSArray *)items changed:(BOOL)changed;  // called after customize sheet is hidden. items is new item list

@end


@interface UITabBar : UIView
- (void)setItems:(NSArray *)items animated:(BOOL)animated;
- (void)beginCustomizingItems:(NSArray *)items;
- (BOOL)endCustomizingAnimated:(BOOL)animated;
- (BOOL)isCustomizing;

@property (nonatomic, assign) id<UITabBarDelegate> delegate;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, assign) UITabBarItem *selectedItem;
@end
