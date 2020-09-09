#import "UIToolbar.h"
#import "UIView.h"

@class UIColor, UINavigationItem, UINavigationBar;

@protocol UINavigationBarDelegate <NSObject>
@optional
- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPushItem:(UINavigationItem *)item;
- (void)navigationBar:(UINavigationBar *)navigationBar didPushItem:(UINavigationItem *)item;
- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;
- (void)navigationBar:(UINavigationBar *)navigationBar didPopItem:(UINavigationItem *)item;
@end

@interface UINavigationBar : UIView
- (void)setItems:(NSArray *)items animated:(BOOL)animated;
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated;
- (UINavigationItem *)popNavigationItemAnimated:(BOOL)animated;

@property (nonatomic, assign) id delegate;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, assign) UIBarStyle barStyle;
@property (nonatomic, readonly, strong) UINavigationItem *topItem;
@property (nonatomic, readonly, strong) UINavigationItem *backItem;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) NSDictionary *titleTextAttributes;
@end
