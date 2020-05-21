#import "UINavigationController.h"
#import "UITabBarController.h"
#import "UINavigationBar.h"
#import "UIToolbar.h"

@interface UIViewController (UIPrivate)
- (void)_removeFromParentViewController;
@end

@implementation UINavigationController {
    UIViewController *_visibleViewController; // 应该就是 topVc
    BOOL _needsDeferredUpdate;
    BOOL _isUpdating;
    BOOL _toolbarHidden;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if ((self=[super initWithNibName:nil bundle:nil])) {
        _navigationBar = [UINavigationBar new];
        _navigationBar.delegate = self;
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
    
    // 这里, iOS 7 之后, 应该发生了变化, _visibleViewController.view 应该可以在 navigationBar 之下了.
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

- (void)_getNavbarRect:(CGRect *)navbarRect contentRect:(CGRect *)contentRect toolbarRect:(CGRect *)toolbarRect forBounds:(CGRect)bounds
{
    const CGRect navbar = CGRectMake(CGRectGetMinX(bounds), CGRectGetMinY(bounds), CGRectGetWidth(bounds), _navigationBar.frame.size.height);
    const CGRect toolbar = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds)-_toolbar.frame.size.height, CGRectGetWidth(bounds), _toolbar.frame.size.height);
    CGRect content = bounds;
    
    if (!self.navigationBarHidden) {
        content.origin.y += CGRectGetHeight(navbar);
        content.size.height -= CGRectGetHeight(navbar);
    }
    
    if (!self.toolbarHidden) {
        content.size.height -= CGRectGetHeight(toolbar);
    }
    
    if (navbarRect)  *navbarRect = navbar;
    if (toolbarRect) *toolbarRect = toolbar;
    if (contentRect) *contentRect = content;
}

// 核心方法. 做内容更改的动画.
- (void)_updateVisibleViewController:(BOOL)animated
{
    _isUpdating = YES;
    
    UIViewController *newVisibleViewController = self.topViewController;
    UIViewController *oldVisibleViewController = _visibleViewController;
    
    const BOOL isPushing = (oldVisibleViewController.parentViewController != nil);
    const BOOL wasNavbarHidden = self.navigationBarHidden;
    
    [oldVisibleViewController beginAppearanceTransition:NO animated:animated];
    [newVisibleViewController beginAppearanceTransition:YES animated:animated];
    
    [self.delegate navigationController:self willShowViewController:newVisibleViewController animated:animated];
    
    _visibleViewController = newVisibleViewController;
    
    const CGRect bounds = self.view.bounds;
    
    CGRect navbarRect;
    CGRect contentRect;
    CGRect toolbarRect;
    [self _getNavbarRect:&navbarRect contentRect:&contentRect toolbarRect:&toolbarRect forBounds:bounds];
    _navigationBar.transform = CGAffineTransformIdentity;
    _navigationBar.frame = navbarRect;
    
    newVisibleViewController.view.transform = CGAffineTransformIdentity;
    newVisibleViewController.view.frame = contentRect;
    
    const CGAffineTransform inStartTransform = isPushing? CGAffineTransformMakeTranslation(bounds.size.width, 0) : CGAffineTransformMakeTranslation(-bounds.size.width, 0);
    const CGAffineTransform outEndTransform = isPushing? CGAffineTransformMakeTranslation(-bounds.size.width, 0) : CGAffineTransformMakeTranslation(bounds.size.width, 0);
    
    CGAffineTransform navbarEndTransform = CGAffineTransformIdentity;
    
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
    
    [UIView animateWithDuration:animated? 0.33 : 0
                     animations:^{
        oldVisibleViewController.view.transform = outEndTransform;
        newVisibleViewController.view.transform = CGAffineTransformIdentity;
        _navigationBar.transform = navbarEndTransform;
    }
                     completion:^(BOOL finished) {
        [oldVisibleViewController.view removeFromSuperview];
        
        _navigationBar.hidden = _navigationBarHidden;
        
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

// 对于 _needsDeferredUpdate, 会在 viewWillLayoutSubviews中进行处理.
- (void)viewWillLayoutSubviews
{
    if (_needsDeferredUpdate) {
        _needsDeferredUpdate = NO;
        [self _updateVisibleViewController:NO];
    }
}

// 就是 self.childViewControllers
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

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController.parentViewController != self) {
        [self addChildViewController:viewController]; // nav 会自动进行ChildVC的添加.
    }
    
    if (animated) {
        [self _updateVisibleViewController:animated];
    } else {
        [self _setNeedsDeferredUpdate];
    }
    // 更新 navigationBar 的视图.
    // viewControler 会提供自己在 navigationBar 中的状态. 如果自定义了, 就用自定义的数据, 否则的化, 就是当前 VC 的 title 组成一个数据.
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
    [_navigationBar popNavigationItemAnimated:animated];
    _navigationBar.delegate = self;
    
    if (animated) {
        [self _updateVisibleViewController:animated];
    } else {
        [self _setNeedsDeferredUpdate];
    }
    
    return formerTopViewController;
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
    if (hide != _navigationBarHidden) {
        _navigationBarHidden = hide;
        
        if (animated && !_isUpdating) {
            CGAffineTransform startTransform = hide? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, -_navigationBar.frame.size.height);
            CGAffineTransform endTransform = hide? CGAffineTransformMakeTranslation(0, -_navigationBar.frame.size.height) : CGAffineTransformIdentity;
            
            CGRect contentRect;
            [self _getNavbarRect:NULL contentRect:&contentRect toolbarRect:NULL forBounds:self.view.bounds];
            
            _navigationBar.transform = startTransform;
            _navigationBar.hidden = NO;
            
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
