#import "UINavigationController.h"
#import "UITabBarController.h"
#import "UINavigationBar.h"
#import "UIToolbar.h"

@interface UIViewController (UIPrivate)
- (void)_removeFromParentViewController;
@end

@implementation UINavigationController {
    UIViewController *_visibleViewController; // 这个记录最上面的 VC.
    BOOL _needsDeferredUpdate;
    BOOL _isUpdating;
    BOOL _toolbarHidden;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if ((self=[super initWithNibName:nil bundle:nil])) {
        // 创建了一个 Bar.
        _navigationBar = [UINavigationBar new];
        _navigationBar.delegate = self; // 原来 Bar 也有 delegate.
        
        // 创建了一个 ToolBar
        _toolbar = [UIToolbar new];
        _toolbarHidden = YES;

        self.viewControllers = @[rootViewController];
    }
    return self;
}

- (void)dealloc
{
    _navigationBar.delegate = nil;
}

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    self.view.clipsToBounds = YES;

    CGRect navbarRect;
    CGRect contentRect;
    CGRect toolbarRect;
    [self _getNavbarRect:&navbarRect contentRect:&contentRect toolbarRect:&toolbarRect forBounds:self.view.bounds];
    
    _toolbar.frame = toolbarRect;
    _navigationBar.frame = navbarRect;
    _visibleViewController.view.frame = contentRect;
    
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _visibleViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // 然后, 自己的 View, 增加了三个子视图.
    [self.view addSubview:_visibleViewController.view];
    [self.view addSubview:_navigationBar];
    [self.view addSubview:_toolbar];
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods
{
    return NO;
}

- (void)_setNeedsDeferredUpdate
{
    _needsDeferredUpdate = YES;
    [self.view setNeedsLayout];
}

- (void)_getNavbarRect:(CGRect *)navbarRect
           contentRect:(CGRect *)contentRect
           toolbarRect:(CGRect *)toolbarRect
             forBounds:(CGRect)bounds
{
    const CGRect navbar = CGRectMake(CGRectGetMinX(bounds),
                                     CGRectGetMinY(bounds),
                                     CGRectGetWidth(bounds),
                                     _navigationBar.frame.size.height);
    const CGRect toolbar = CGRectMake(CGRectGetMinX(bounds),
                                      CGRectGetMaxY(bounds)-_toolbar.frame.size.height,
                                      CGRectGetWidth(bounds),
                                      _toolbar.frame.size.height);
    CGRect content = bounds; // 内容, 原本是和 View 一样的.
    
    if (!self.navigationBarHidden) {
        content.origin.y += CGRectGetHeight(navbar);
        content.size.height -= CGRectGetHeight(navbar);
    } // 因为 NavBar 不隐藏, 内容缩减.

    if (!self.toolbarHidden) {
        content.size.height -= CGRectGetHeight(toolbar);
    } // 因为 ToolBar 不隐藏, 内容缩减.
    
    if (navbarRect)  *navbarRect = navbar;
    if (toolbarRect) *toolbarRect = toolbar;
    if (contentRect) *contentRect = content;
}

- (void)viewWillLayoutSubviews
{
    if (_needsDeferredUpdate) {
        _needsDeferredUpdate = NO;
        [self _updateVisibleViewController:NO];
    }
}

// 这里, copy 一份资源出去, 不让外界有机会破坏内部的值.
- (NSArray *)viewControllers
{
    return [self.childViewControllers copy];
}

- (void)setViewControllers:(NSArray *)newViewControllers animated:(BOOL)animated
{
    if (![newViewControllers isEqualToArray:self.viewControllers]) {
        // find the controllers we used to have that we won't be using anymore
        NSMutableArray *removeViewControllers = [self.viewControllers mutableCopy];
        [removeViewControllers removeObjectsInArray:newViewControllers];
        
        // these view controllers are not in the new collection, so we must remove them as children
        // I'm pretty sure the real UIKit doesn't attempt to be so clever..
        for (UIViewController *controller in removeViewControllers) {
            [controller willMoveToParentViewController:nil];
            [controller removeFromParentViewController];
        }
        
        // reset the nav bar
        _navigationBar.items = nil;
        
        // add them back in one-by-one and only apply animation to the last one (if any)
        for (UIViewController *controller in newViewControllers) {
            [self pushViewController:controller animated:(animated && (controller == [newViewControllers lastObject]))];
        }
    }
}

- (void)setViewControllers:(NSArray *)newViewControllers
{
    [self setViewControllers:newViewControllers animated:NO];
}

- (UIViewController *)topViewController
{
    return [self.childViewControllers lastObject];
}

// 核心, 就是 push, pop 的实现思路.

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    // this logic matches with the cleverness in setViewControllers which the real UIKit probably doens't do
    // and probably isn't necessary :)
    if (viewController.parentViewController != self) {
        
        // note that -addChildViewController will call -willMoveToParentViewController: and that
        // there's no matching call to -didMoveToParentViewController: here which is usually
        // required. In my tests, it seems like the real UIKit hardly ever correctly calls the
        // -didMoveToParentViewController: method on it's navigation controller children which
        // makes me slightly crazy inside. I blame legacy (since child containment wasn't added
        // until iOS 5), but it's still stupid.
        [self addChildViewController:viewController];
    }
    
    if (animated) {
        [self _updateVisibleViewController:animated];
    } else {
        [self _setNeedsDeferredUpdate];
    }

    // 这里, 主动调用了 bar 的更新方法.
    [_navigationBar pushNavigationItem:viewController.navigationItem animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    // don't allow popping the rootViewController
    if ([self.viewControllers count] <= 1) {
        return nil;
    }

    UIViewController *formerTopViewController = self.topViewController;
    
    // the real thing seems to only bother calling -willMoveToParentViewController:
    // here if the popped controller is the currently visible one. I have no idea why.
    // if you pop several in a row, the ones buried in the stack don't seem to get called.
    // it is possible that the real implementation is fancier and tracks if a child has
    // been fully ever added or not before making this determination, but I haven't
    // tried to test for that case yet since this was an easy thing to do to replicate
    // the real world behavior I was seeing at the time of this writing.
    if (formerTopViewController == _visibleViewController) {
        [formerTopViewController willMoveToParentViewController:nil];
    }

    // the real thing seems to cheat here and removes the parent immediately even if animated
    [formerTopViewController _removeFromParentViewController];

    // pop the nav bar - note that it's setting the delegate to nil and back because we use the nav bar's
    // -navigationBar:shouldPopItem: delegate method to determine when the user clicks the back button
    // but that method is also called when we do an animated pop like this, so this works around the cycle.
    // I don't love it.
    _navigationBar.delegate = nil;
    // 主动调用 bar 的更新方法.
    [_navigationBar popNavigationItemAnimated:animated];
    _navigationBar.delegate = self;
    
    if (animated) {
        [self _updateVisibleViewController:animated];
    } else {
        [self _setNeedsDeferredUpdate];
    }

	return formerTopViewController;
}

// 核心方法, 维护 View 的逻辑的合理性.
- (void)_updateVisibleViewController:(BOOL)animated
{
    _isUpdating = YES;
    
    UIViewController *newVisibleViewController = self.topViewController;
    UIViewController *oldVisibleViewController = _visibleViewController;
    
    const BOOL isPushing = (oldVisibleViewController.parentViewController != nil);
    const BOOL wasToolbarHidden = self.toolbarHidden;
    const BOOL wasNavbarHidden = self.navigationBarHidden;
        
    // 参与变化的两个 VC, 进行开始方法的触发.
    [oldVisibleViewController beginAppearanceTransition:NO animated:animated];
    [newVisibleViewController beginAppearanceTransition:YES animated:animated];
    
    [self.delegate navigationController:self willShowViewController:newVisibleViewController animated:animated];

    _visibleViewController = newVisibleViewController;

    const CGRect bounds = self.view.bounds;

    CGRect navbarRect;
    CGRect contentRect;
    CGRect toolbarRect;
    [self _getNavbarRect:&navbarRect contentRect:&contentRect toolbarRect:&toolbarRect forBounds:bounds];
    
    _toolbar.transform = CGAffineTransformIdentity;
    _toolbar.frame = toolbarRect;

    _navigationBar.transform = CGAffineTransformIdentity;
    _navigationBar.frame = navbarRect;

    newVisibleViewController.view.transform = CGAffineTransformIdentity;
    newVisibleViewController.view.frame = contentRect;
    
    const CGAffineTransform inStartTransform = isPushing? CGAffineTransformMakeTranslation(bounds.size.width, 0) : CGAffineTransformMakeTranslation(-bounds.size.width, 0);
    const CGAffineTransform outEndTransform = isPushing? CGAffineTransformMakeTranslation(-bounds.size.width, 0) : CGAffineTransformMakeTranslation(bounds.size.width, 0);

    CGAffineTransform toolbarEndTransform = CGAffineTransformIdentity;
    CGAffineTransform navbarEndTransform = CGAffineTransformIdentity;
    
    // 修改 ToolBar 的数据.
    if (wasToolbarHidden && !_toolbarHidden) {
        _toolbar.transform = inStartTransform;
        _toolbar.hidden = NO;
        _toolbar.items = newVisibleViewController.toolbarItems;
    } else if (!wasToolbarHidden && _toolbarHidden) {
        toolbarEndTransform = outEndTransform;
        _toolbar.transform = CGAffineTransformIdentity;
        _toolbar.hidden = NO;
    } else {
        [_toolbar setItems:newVisibleViewController.toolbarItems animated:animated];
    }
    
    if (wasNavbarHidden && !_navigationBarHidden) {
        _navigationBar.transform = inStartTransform;
        _navigationBar.hidden = NO;
    } else if (!wasNavbarHidden && _navigationBarHidden) {
        navbarEndTransform = outEndTransform;
        _navigationBar.transform = CGAffineTransformIdentity;
        _navigationBar.hidden = NO;
    }

    newVisibleViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:newVisibleViewController.view atIndex:0];
    newVisibleViewController.view.transform = inStartTransform;
        
    // 做动画, Nav 的变化效果.
    [UIView animateWithDuration:animated? 0.33 : 0
                     animations:^{
                         oldVisibleViewController.view.transform = outEndTransform;
                         newVisibleViewController.view.transform = CGAffineTransformIdentity;
                         _toolbar.transform = toolbarEndTransform;
                         _navigationBar.transform = navbarEndTransform;
                     }
                     completion:^(BOOL finished) {
                         [oldVisibleViewController.view removeFromSuperview];
                         
                         _toolbar.hidden = _toolbarHidden;
                         _navigationBar.hidden = _navigationBarHidden;

                    // 参与变化的两个 VC, 进行结束方法的触发.
                         [oldVisibleViewController endAppearanceTransition];
                         [newVisibleViewController endAppearanceTransition];
                         
                         // not sure if this is safe or not, really, but the real one must do something along these lines?
                         // it could perform this check in a variety of ways, though, with subtly different results so I'm
                         // not sure what's best. this seemed generally safest.
                         if (oldVisibleViewController && isPushing) {
                             [oldVisibleViewController didMoveToParentViewController:nil];
                         } else {
                             [newVisibleViewController didMoveToParentViewController:self];
                         }
                         
                         [self.delegate navigationController:self didShowViewController:newVisibleViewController animated:animated];
                     }];

    _isUpdating = NO;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSMutableArray *popped = [[NSMutableArray alloc] init];

    if ([self.viewControllers containsObject:viewController]) {
        while (self.topViewController != viewController) {
            UIViewController *poppedController = [self popViewControllerAnimated:animated];
            if (poppedController) {
                [popped addObject:poppedController];
            } else {
                break;
            }
        }
    }
    
    // 返回所有弹出的对象.
    return popped;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    return [self popToViewController:[self.viewControllers objectAtIndex:0] animated:animated];
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item
{
    // always initiate an animated pop and return NO so that the nav bar itself doesn't take it upon itself
    // to pop the item, instead popViewControllerAnimated: will command it to do so later.
    [self popViewControllerAnimated:YES];
    return NO;
}

// 这里, 和 NavBar 的思路是一样的.
- (void)setToolbarHidden:(BOOL)hide animated:(BOOL)animated
{
    if (hide != _toolbarHidden) {
        _toolbarHidden = hide;

        if (animated && !_isUpdating) {
            CGAffineTransform startTransform = hide? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, _toolbar.frame.size.height);
            CGAffineTransform endTransform = hide? CGAffineTransformMakeTranslation(0, _toolbar.frame.size.height) : CGAffineTransformIdentity;
            
            CGRect contentRect;
            [self _getNavbarRect:NULL contentRect:&contentRect toolbarRect:NULL forBounds:self.view.bounds];
            
            _toolbar.transform = startTransform;
            _toolbar.hidden = NO;
            
            [UIView animateWithDuration:0.15
                             animations:^{
                                 _visibleViewController.view.frame = contentRect;
                                 _toolbar.transform = endTransform;
                             }
                             completion:^(BOOL finished) {
                                 _toolbar.transform = CGAffineTransformIdentity;
                                 _toolbar.hidden = _toolbarHidden;
                             }];
        } else {
            _toolbar.hidden = _toolbarHidden;
        }
    }
}

- (void)setToolbarHidden:(BOOL)hidden
{
    [self setToolbarHidden:hidden animated:NO];
}

- (BOOL)isToolbarHidden
{
    return _toolbarHidden || self.topViewController.hidesBottomBarWhenPushed;
}

- (void)setContentSizeForViewInPopover:(CGSize)newSize
{
    self.topViewController.contentSizeForViewInPopover = newSize;
}

- (CGSize)contentSizeForViewInPopover
{
    return self.topViewController.contentSizeForViewInPopover;
}

- (void)setNavigationBarHidden:(BOOL)hide animated:(BOOL)animated;
{
    if (hide == _navigationBarHidden) { return; }
    _navigationBarHidden = hide;
    
    if (animated && !_isUpdating) {
        CGAffineTransform startTransform = hide? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -_navigationBar.frame.size.height);
        CGAffineTransform endTransform = hide? CGAffineTransformMakeTranslation(0, -_navigationBar.frame.size.height) : CGAffineTransformIdentity;
        
        // 这里, 因为 Bar 的可见性变化了, 所以 content 的 Frame 也要发生变化.
        CGRect contentRect;
        [self _getNavbarRect:NULL contentRect:&contentRect toolbarRect:NULL forBounds:self.view.bounds];
        
        _navigationBar.transform = startTransform;
        _navigationBar.hidden = NO;
        
        // 使用一个简单的动画, 进行 Bar 的隐藏或者显示.
        [UIView animateWithDuration:0.15
                         animations:^{
                             _visibleViewController.view.frame = contentRect;
                             _navigationBar.transform = endTransform;
                         }
                         completion:^(BOOL finished) {
                             _navigationBar.transform = CGAffineTransformIdentity;
                             _navigationBar.hidden = _navigationBarHidden;
                         }];
    } else {
        _navigationBar.hidden = _navigationBarHidden;
    }
}

- (void)setNavigationBarHidden:(BOOL)navigationBarHidden
{
    [self setNavigationBarHidden:navigationBarHidden animated:NO];
}

- (UIViewController *)defaultResponderChildViewController
{
    return self.topViewController;
}

@end
