#import "UIResponder.h"
#import "UIApplication.h"
#import "UISearchDisplayController.h"
#import "UITabBarItem.h"

@class UITabBarController;

typedef NS_ENUM(NSInteger, UIModalPresentationStyle) {
    UIModalPresentationFullScreen = 0,
    UIModalPresentationPageSheet,
    UIModalPresentationFormSheet,
    UIModalPresentationCurrentContext,
};

typedef NS_ENUM(NSInteger, UIModalTransitionStyle) {
    UIModalTransitionStyleCoverVertical = 0,
    UIModalTransitionStyleFlipHorizontal,
    UIModalTransitionStyleCrossDissolve,
    UIModalTransitionStylePartialCurl,
};

@class UINavigationItem, UINavigationController, UIBarButtonItem, UISplitViewController;

// VC 主要做的是, 管理 View 的切换的工作. 他更多像是一个数据类, 程序通过控制这个数据类, 来进行它所存储的 view 的各种显示, 隐藏的管理. 在不同的操作下, 调用不同的动画, 将 view 添加或者删除在当前的屏幕上. 也就是说, 有了 VC 的这一层中介, 可以将 View 的转换过程进行封装.

@interface UIViewController : UIResponder
- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle;	// won't load a nib no matter what you do!

- (BOOL)isViewLoaded;
- (void)loadView;
- (void)viewDidLoad;
- (void)viewDidUnload;

- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;

- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;

// these are deprecated on iOS 6
- (void)presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated;		// works, but not exactly correctly.
- (void)dismissModalViewControllerAnimated:(BOOL)animated;												// see comments in dismissModalViewController

- (void)didReceiveMemoryWarning;	// is called when UIApplicationDidReceiveMemoryWarningNotification is posted, which is currently only done by private API for.. fun, I guess?

- (void)setToolbarItems:(NSArray *)toolbarItems animated:(BOOL)animated;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
- (UIBarButtonItem *)editButtonItem;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration;
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation;

- (BOOL)isMovingFromParentViewController;
- (BOOL)isMovingToParentViewController;
- (BOOL)isBeingPresented;
- (BOOL)isBeingDismissed;

- (void)addChildViewController:(UIViewController *)childController;
- (void)removeFromParentViewController;
- (BOOL)shouldAutomaticallyForwardRotationMethods;
- (BOOL)shouldAutomaticallyForwardAppearanceMethods;
- (void)transitionFromViewController:(UIViewController *)fromViewController toViewController:(UIViewController *)toViewController duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated;    // iOS 6+
- (void)endAppearanceTransition;                                                // iOS 6+

- (void)willMoveToParentViewController:(UIViewController *)parent;
- (void)didMoveToParentViewController:(UIViewController *)parent;

@property (nonatomic, readonly, copy) NSString *nibName;
@property (nonatomic, readonly, retain) NSBundle *nibBundle;
@property (nonatomic, retain) UIView *view;
@property (nonatomic, assign) BOOL wantsFullScreenLayout;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly, retain) UINavigationItem *navigationItem;
@property (nonatomic, retain) NSArray *toolbarItems;
@property (nonatomic, getter=isEditing) BOOL editing;
@property (nonatomic) BOOL hidesBottomBarWhenPushed;

@property (nonatomic, readwrite) CGSize contentSizeForViewInPopover;
@property (nonatomic, readwrite, getter=isModalInPopover) BOOL modalInPopover;

@property (nonatomic, assign) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic, assign) UIModalTransitionStyle modalTransitionStyle;
@property (nonatomic, assign) BOOL definesPresentationContext;
@property (nonatomic, assign) BOOL providesPresentationContextTransitionStyle;

@property (nonatomic, readonly) UIViewController *parentViewController;

@property (nonatomic, readonly) NSArray *childViewControllers;
@property (nonatomic, readonly) UIViewController *presentingViewController;
@property (nonatomic, readonly) UIViewController *presentedViewController;

@property (nonatomic, readonly, retain) UINavigationController *navigationController;
@property (nonatomic, readonly, retain) UISplitViewController *splitViewController;
@property (nonatomic, readonly, retain) UITabBarController *tabBarController;
@property (nonatomic, readonly, retain) UISearchDisplayController *searchDisplayController;
@property (nonatomic, readonly, retain) UIViewController *modalViewController;

@property (nonatomic, retain) UITabBarItem *tabBarItem;
@end
