#import "UIViewControllerAppKitIntegration.h"
#import "UIView+UIPrivate.h"
#import "UIScreen.h"
#import "UIWindow.h"
#import "UIScreen.h"
#import "UINavigationItem.h"
#import "UIBarButtonItem.h"
#import "UINavigationController.h"
#import "UISplitViewController.h"
#import "UIToolbar.h"
#import "UIScreen.h"
#import "UITabBarController.h"

typedef NS_ENUM(NSInteger, _UIViewControllerParentageTransition) {
    _UIViewControllerParentageTransitionNone = 0,
    _UIViewControllerParentageTransitionToParent,
    _UIViewControllerParentageTransitionFromParent,
};

@implementation UIViewController {
    UIView *_view;
    UINavigationItem *_navigationItem; // 和 navigationBar 配套使用的数据.
    NSMutableArray *_childViewControllers;
    __unsafe_unretained UIViewController *_parentViewController;
    
    NSUInteger _appearanceTransitionStack;
    BOOL _appearanceTransitionIsAnimated;
    BOOL _viewIsAppearing; // 这个值, 用来记录当前 view 的显示状态.
    _UIViewControllerParentageTransition _parentageTransition;
}

- (id)init
{
    return [self initWithNibName:nil bundle:nil];
}

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    /*
     在 VC 的构造方法内部, 就进行了didReceiveMemoryWarning 的注册, 所以我们才能在这里面写内存的处理.
     */
    if ((self=[super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:[UIApplication sharedApplication]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:[UIApplication sharedApplication]];
    [_view _setViewController:nil];
}


/*
 VC 的 nextResponder, 就是 view 的 superView
 */
- (UIResponder *)nextResponder
{
    return _view.superview;
}

- (UIViewController *)defaultResponderChildViewController
{
    return nil;
}

- (UIResponder *)defaultResponder
{
    return nil;
}

- (BOOL)isViewLoaded
{
    return (_view != nil);
}

/*
 View 的懒加载过程.
 */
- (UIView *)view
{
    if ([self isViewLoaded]) {
        return _view;
    } else {
        const BOOL wereEnabled = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        [self loadView]; // 加载 View 的过程, 默认是生成一个 UIView, 不通过 nib 进行加载.
        [self viewDidLoad]; // 然后调用 viewDidLoad.
        [UIView setAnimationsEnabled:wereEnabled];
        return _view;
    }
}

/*
 这里, 其实有着一个 View 的自定义过程. 默认的是通过 UIView, 如果是 Nib 加载的话, 会加载 Nib 的 view.
 */
- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0,0,320,480)];
}

/*
 模板方法里面, 最重要的一个切口.
 */
- (void)viewDidLoad
{
}

/*
 这几个 view 相关的调用, 是但当自己关联的 View 进行 SuperView 的修改的时候, 主动调用的.
 */
- (void)viewWillAppear:(BOOL)animated
{
}
- (void)viewDidAppear:(BOOL)animated
{
}
- (void)viewWillDisappear:(BOOL)animated
{
}
- (void)viewDidDisappear:(BOOL)animated
{
}

/*
 这是在自己关联的 View, 进行 layoutSubview 的时候, 主动调用的.
 */
- (void)viewWillLayoutSubviews
{
}

- (void)viewDidLayoutSubviews
{
}

- (UIInterfaceOrientation)interfaceOrientation
{
    return (UIInterfaceOrientation)1;
}

/*
 这就是为了 NavVC, 特地插入的一个数据, 完全是 Nav 相关的.
 */
- (UINavigationItem *)navigationItem
{
    if (!_navigationItem) {
        _navigationItem = [[UINavigationItem alloc] initWithTitle:self.title];
    }
    return _navigationItem;
}

- (void)setTitle:(NSString *)title
{
    if (![_title isEqual:title]) {
        _title = [title copy];
        _navigationItem.title = _title;
    }
}

- (void)setToolbarItems:(NSArray *)theToolbarItems animated:(BOOL)animated
{
    if (![_toolbarItems isEqual:theToolbarItems]) {
        _toolbarItems = theToolbarItems;
        [self.navigationController.toolbar setItems:_toolbarItems animated:animated];
    }
}

- (void)setToolbarItems:(NSArray *)theToolbarItems
{
    [self setToolbarItems:theToolbarItems animated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    _editing = editing;
}

- (void)setEditing:(BOOL)editing
{
    [self setEditing:editing animated:NO];
}

- (UIBarButtonItem *)editButtonItem
{
    // this should really return a fancy bar button item that toggles between edit/done and sends setEditing:animated: messages to this controller
    return nil;
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion
{
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
}

// 虽然这两个方法没有实现, 但是我们知道, VC 的 view 其实就在 View 的 hieracry 中. VC 更多的是将 View 相关的一系列工作转移到一个固定的类中.
- (void)presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated
{
    /*
     if (!_modalViewController && _modalViewController != self) {
     _modalViewController = modalViewController;
     [_modalViewController _setParentViewController:self];
     
     UIWindow *window = self.view.window;
     UIView *selfView = self.view;
     UIView *newView = _modalViewController.view;
     
     newView.autoresizingMask = selfView.autoresizingMask;
     newView.frame = _wantsFullScreenLayout? window.screen.bounds : window.screen.applicationFrame;
     
     [window addSubview:newView];
     [_modalViewController viewWillAppear:animated];
     
     [self viewWillDisappear:animated];
     selfView.hidden = YES;		// I think the real one may actually remove it, which would mean needing to remember the superview, I guess? Not sure...
     [self viewDidDisappear:animated];
     
     [_modalViewController viewDidAppear:animated];
     }
     */
}

- (void)dismissModalViewControllerAnimated:(BOOL)animated
{
    /*
     // NOTE: This is not implemented entirely correctly - the actual dismissModalViewController is somewhat subtle.
     // There is supposed to be a stack of modal view controllers that dismiss in a specific way,e tc.
     // The whole system of related view controllers is not really right - not just with modals, but everything else like
     // navigationController, too, which is supposed to return the nearest nav controller down the chain and it doesn't right now.
     
     if (_modalViewController) {
     
     // if the modalViewController being dismissed has a modalViewController of its own, then we need to go dismiss that, too.
     // otherwise things can be left hanging around.
     if (_modalViewController.modalViewController) {
     [_modalViewController dismissModalViewControllerAnimated:animated];
     }
     
     self.view.hidden = NO;
     [self viewWillAppear:animated];
     
     [_modalViewController.view removeFromSuperview];
     [_modalViewController _setParentViewController:nil];
     _modalViewController = nil;
     
     [self viewDidAppear:animated];
     } else {
     [self.parentViewController dismissModalViewControllerAnimated:animated];
     }
     */
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
}

// 遍历 parentVC.
- (id)_nearestParentViewControllerThatIsKindOf:(Class)c
{
    UIViewController *controller = _parentViewController;
    
    while (controller && ![controller isKindOfClass:c]) {
        controller = [controller parentViewController];
    }
    
    return controller;
}

- (UINavigationController *)navigationController
{
    return [self _nearestParentViewControllerThatIsKindOf:[UINavigationController class]];
}

- (UISplitViewController *)splitViewController
{
    return [self _nearestParentViewControllerThatIsKindOf:[UISplitViewController class]];
}

- (BOOL)isMovingFromParentViewController
{
    // Docs don't say anything about being required to call super for -willMoveToParentViewController: and people
    // on StackOverflow seem to tell each other they can override the method without calling super. Based on that,
    // I have no freakin' idea how this method here is meant to know when to return YES...
    
    // I'm inclined to think that the docs are just unclear and that -willMoveToParentViewController: and
    // -didMoveToParentViewController: must have to do *something* for this to work without ambiguity.
    
    // Now that I think about it some more, I suspect that it is far better to assume the docs imply you must call
    // super when you override a method *unless* it says not to. If that assumption is sound, then in that case it
    // suggests that when overriding -willMoveToParentViewController: and -didMoveToParentViewController: you are
    // expected to call super anyway, which means I could put some implementation in the base class versions safely.
    // Generally docs do tend to say things like, "parent implementation does nothing" when they mean you can skip
    // the call to super, and the docs currently say no such thing for -will/didMoveToParentViewController:.
    
    // In all likely hood, all that would happen if you didn't call super from a -will/didMoveToParentViewController:
    // override is that -isMovingFromParentViewController and -isMovingToParentViewController would return the
    // wrong answer, and if you never use them, you'll never even notice that bug!
    
    return (_appearanceTransitionStack > 0) && (_parentageTransition == _UIViewControllerParentageTransitionFromParent);
}

- (BOOL)isMovingToParentViewController
{
    return (_appearanceTransitionStack > 0) && (_parentageTransition == _UIViewControllerParentageTransitionToParent);
}

- (BOOL)isBeingPresented
{
    // TODO
    return (_appearanceTransitionStack > 0) && (NO);
}

- (BOOL)isBeingDismissed
{
    // TODO
    return (_appearanceTransitionStack > 0) && (NO);
}

- (UIViewController *)presentingViewController
{
    // TODO
    return nil;
}

- (UIViewController *)presentedViewController
{
    // TODO
    return nil;
}

// copy, 不给外界操作内部数据的机会.
- (NSArray *)childViewControllers
{
    return [_childViewControllers copy];
}

- (void)addChildViewController:(UIViewController *)childController
{
    if (!_childViewControllers) {
        _childViewControllers = [NSMutableArray arrayWithCapacity:1];
    }
    
    [childController willMoveToParentViewController:self];
    [_childViewControllers addObject:childController];
    childController->_parentViewController = self;
}

// 通过一个专门的有含义的方法, 维护数据的统一.
- (void)_removeFromParentViewController
{
    if (_parentViewController) {
        [_parentViewController->_childViewControllers removeObject:self];
        if ([_parentViewController->_childViewControllers count] == 0) {
            _parentViewController->_childViewControllers = nil;
        }
        _parentViewController = nil;
    }
}

- (void)removeFromParentViewController
{
    [self _removeFromParentViewController];
    [self didMoveToParentViewController:nil]; // 暴露给外界的一个借口.
}

- (BOOL)shouldAutomaticallyForwardRotationMethods
{
    return YES;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return YES;
}

// 这是一个 ContainerVC 的事情, 如果它要更改 subView 的显示, 就要用调用这个方法. 不过我们经常不调用这个方法, 而是直接 removeFromSuperView, addSubView 了. 在这个方法的内部, 会有着 beginAppearance, endAppearance 的调用, 管理着 View 的添加的删除. 伴随着一个转场动画.
/*
 */
- (void)transitionFromViewController:(UIViewController *)fromViewController
                    toViewController:(UIViewController *)toViewController
                            duration:(NSTimeInterval)duration
                             options:(UIViewAnimationOptions)options
                          animations:(void (^)(void))animations
                          completion:(void (^)(BOOL finished))completion
{
    const BOOL animated = (duration > 0);
    
    [fromViewController beginAppearanceTransition:NO animated:animated]; // 通知开始转场 添加
    [toViewController beginAppearanceTransition:YES animated:animated]; // 通知开始转场 去除
    
    // 一个简单的转场动画
    [UIView transitionWithView:self.view
                      duration:duration
                       options:options
                    animations:^{
        if (animations) {
            animations();
        }
        [self.view addSubview:toViewController.view];
    }
                    completion:^(BOOL finished) {
        if (completion) {
            completion(finished);
        }
        [fromViewController.view removeFromSuperview];
        [fromViewController endAppearanceTransition]; // 通知结束转场
        [toViewController endAppearanceTransition]; // 通知结束转场.
    }];
}

- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated
{
    if (_appearanceTransitionStack == 0 ||
        (_appearanceTransitionStack > 0 && _viewIsAppearing != isAppearing)) {
        _appearanceTransitionStack = 1;
        _appearanceTransitionIsAnimated = animated;
        _viewIsAppearing = isAppearing;
        if ([self shouldAutomaticallyForwardAppearanceMethods]) {
            for (UIViewController *child in self.childViewControllers) {
                if ([child isViewLoaded] && [child.view isDescendantOfView:self.view]) {
                    [child beginAppearanceTransition:isAppearing animated:animated];
                }
            }
        }
        
        if (_viewIsAppearing) {
            [self view];    // ensures the view is loaded before viewWillAppear: happens
            [self viewWillAppear:_appearanceTransitionIsAnimated]; // 在这里, 通知 VC.
        } else {
            [self viewWillDisappear:_appearanceTransitionIsAnimated]; // 在这里, 通知 VC.
        }
    } else {
        _appearanceTransitionStack++;
    }
}

- (void)endAppearanceTransition
{
    if (_appearanceTransitionStack > 0) {
        _appearanceTransitionStack--;
        if (_appearanceTransitionStack == 0) {
            if ([self shouldAutomaticallyForwardAppearanceMethods]) {
                for (UIViewController *child in self.childViewControllers) {
                    [child endAppearanceTransition];
                }
            }
            if (_viewIsAppearing) {
                [self viewDidAppear:_appearanceTransitionIsAnimated]; // 在这里, 通知 VC.
            } else {
                [self viewDidDisappear:_appearanceTransitionIsAnimated];
            }
        }
    }
}

- (void)willMoveToParentViewController:(UIViewController *)parent
{
    if (parent) {
        _parentageTransition = _UIViewControllerParentageTransitionToParent;
    } else {
        _parentageTransition = _UIViewControllerParentageTransitionFromParent;
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    _parentageTransition = _UIViewControllerParentageTransitionNone;
}

@end
