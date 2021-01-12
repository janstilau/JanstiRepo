#import <Foundation/Foundation.h>

@class UIBarButtonItem, UIView;

// The items that a navigation bar displays when the associated view controller is visible.

// 这里也就是说, 这个 Item, 就是给 NavgationBar 使用的. 每个 VC 都应该有, 因为 NavigationVC 需要他们配置 Bar 的变化.
// 摩擦的 MCViewController, 没有使用这个一套体系, 而是自己创建了一个 NavgationBar, 每个 VC 自己管理.
// When building a navigation interface, each view controller that you push onto the navigation stack must have a UINavigationItem object that contains the buttons and views you want to display in the navigation bar. The managing UINavigationController object uses the navigation items of the topmost two view controllers to populate the navigation bar with content.

// 这就是一个数据类, 主要还是要看 bar 那里怎么使用.

@interface UINavigationItem : NSObject

@property (nonatomic, copy) NSString *title; // 就是记录 VC 的标题, Bar 会展示到最中央. 也会用到 Back 视图.
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, strong) UIBarButtonItem *backBarButtonItem; // 如果, 想要自定义返回 View, 就定制该值.
@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;
@property (nonatomic, strong) UIView *titleView;
@property (nonatomic, assign) BOOL hidesBackButton;

- (id)initWithTitle:(NSString *)title;
- (void)setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;
- (void)setHidesBackButton:(BOOL)hidesBackButton animated:(BOOL)animated;

@end
