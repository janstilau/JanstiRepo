#import "UINavigationBar.h"
#import "UIGraphics.h"
#import "UIColor.h"
#import "UILabel.h"
#import "UINavigationItem+UIPrivate.h"
#import "UIFont.h"
#import "UIImage+UIPrivate.h"
#import "UIBarButtonItem.h"
#import "UIButton.h"

static const UIEdgeInsets kButtonEdgeInsets = {2,2,2,2};
static const CGFloat kMinButtonWidth = 30;
static const CGFloat kMaxButtonWidth = 200;
static const CGFloat kMaxButtonHeight = 24;
static const CGFloat kBarHeight = 28;

static const NSTimeInterval kAnimationDuration = 0.33;

typedef NS_ENUM(NSInteger, _UINavigationBarTransition) {
    _UINavigationBarTransitionNone = 0,
    _UINavigationBarTransitionPush,
    _UINavigationBarTransitionPop,
};

// 一个 navgationBar 在一个 NavigationController 里面, 然后根据各个 item 展示自己的内容.
@implementation UINavigationBar {
    NSMutableArray<UINavigationItem*>*_itemStack;
    
    UIView *_leftView;
    UIView *_centerView;
    UIView *_rightView;
    
    struct {
        unsigned shouldPushItem : 1;
        unsigned didPushItem : 1;
        unsigned shouldPopItem : 1;
        unsigned didPopItem : 1;
    } _delegateHas;
}

+ (void)_setBarButtonSize:(UIView *)view
{
    CGRect frame = view.frame;
    frame.size = [view sizeThatFits:CGSizeMake(kMaxButtonWidth,kMaxButtonHeight)];
    frame.size.height = kMaxButtonHeight;
    frame.size.width = MAX(frame.size.width,kMinButtonWidth);
    view.frame = frame;
}

+ (UIButton *)_backButtonWithTitle:(NSString *)title
{
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setBackgroundImage:[UIImage _backButtonImage] forState:UIControlStateNormal];
    [backButton setBackgroundImage:[UIImage _highlightedBackButtonImage] forState:UIControlStateHighlighted];
    [backButton setTitle:(title ?: @"Back") forState:UIControlStateNormal];
    backButton.titleLabel.font = [UIFont systemFontOfSize:11];
    backButton.contentEdgeInsets = UIEdgeInsetsMake(0,15,0,7);
    [backButton addTarget:nil action:@selector(_backButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self _setBarButtonSize:backButton];
    return backButton;
}

+ (UIView *)_viewWithBarButtonItem:(UIBarButtonItem *)item
{
    if (!item) return nil;
    
    if (item.customView) {
        [self _setBarButtonSize:item.customView];
        return item.customView;
    } else {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setBackgroundImage:[UIImage _toolbarButtonImage] forState:UIControlStateNormal];
        [button setBackgroundImage:[UIImage _highlightedToolbarButtonImage] forState:UIControlStateHighlighted];
        [button setTitle:item.title forState:UIControlStateNormal];
        [button setImage:item.image forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:11];
        button.contentEdgeInsets = UIEdgeInsetsMake(0,7,0,7);
        [button addTarget:item.target action:item.action forControlEvents:UIControlEventTouchUpInside];
        [self _setBarButtonSize:button];
        return button;
    }
}

- (id)initWithFrame:(CGRect)frame
{
    frame.size.height = kBarHeight;
    
    if ((self=[super initWithFrame:frame])) {
        _itemStack = [[NSMutableArray alloc] init];
        _barStyle = UIBarStyleDefault;
        _tintColor = [UIColor colorWithRed:21/255.f green:21/255.f blue:25/255.f alpha:1];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_navigationItemDidChange:) name:UINavigationItemDidChange object:nil];
    }
    return self;
}

- (UINavigationItem *)topItem
{
    return [_itemStack lastObject];
}

- (UINavigationItem *)backItem
{
    return ([_itemStack count] <= 1)? nil : [_itemStack objectAtIndex:[_itemStack count]-2];
}

- (void)_backButtonTapped:(id)sender
{
    [self popNavigationItemAnimated:YES];
}


// 核心方法.

/**
 从这个方法可以清楚, navigationBar 就是是一个 根据栈管理自己的 left, right, centerView 的顶部试图.  这个顶部视图, 根据 UINavigationItem 存储了一些数据信息, 这些信息, 可以用来控制 navigationBar 的展示.
 */

- (void)updateViewsWithTransition:(_UINavigationBarTransition)transition animated:(BOOL)animated
{
    {
        // 当前在 navgationBar 上面的 view 的动态消失.
        NSMutableArray *previousViews = [[NSMutableArray alloc] init];
        
        if (_leftView) [previousViews addObject:_leftView];
        if (_centerView) [previousViews addObject:_centerView];
        if (_rightView) [previousViews addObject:_rightView];
        
        if (animated) {
            CGFloat moveCenterBy = self.bounds.size.width - ((_centerView)? _centerView.frame.origin.x : 0);
            CGFloat moveLeftBy = self.bounds.size.width * 0.33f;
            
            if (transition == _UINavigationBarTransitionPush) {
                moveCenterBy *= -1.f;
                moveLeftBy *= -1.f;
            }
            
            [UIView animateWithDuration:kAnimationDuration * 0.8
                                  delay:kAnimationDuration * 0.2
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^(void) {
                _leftView.alpha = 0;
                _rightView.alpha = 0;
                _centerView.alpha = 0;
            }
                             completion:NULL];
            [UIView animateWithDuration:kAnimationDuration
                             animations:^(void) {
                if (_leftView)     _leftView.frame = CGRectOffset(_leftView.frame, moveLeftBy, 0);
                if (_centerView)   _centerView.frame = CGRectOffset(_centerView.frame, moveCenterBy, 0);
            }
                             completion:^(BOOL finished) {
                [previousViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
            }];
        } else {
            [previousViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
    }
    
    UINavigationItem *topItem = self.topItem;
    
    if (topItem) {
        UINavigationItem *backItem = self.backItem;
        
        CGRect leftFrame = CGRectZero;
        CGRect rightFrame = CGRectZero;
        
        // 根据 item 里面的属性, 创建 leftView
        // 这里, backBarButtonItem 指的是, item 在 top 下方的时候, 自己想要在 back 的位置展示的信息.
        // leftBarButtonItem 指的是, 当 item 在 top 的时候, 自己的 back 应该显示的信息. 都算是自定义的一个切口.
        if (backItem) {
            _leftView = [[self class] _backButtonWithTitle:backItem.backBarButtonItem.title ?: backItem.title];
        } else {
            _leftView = [[self class] _viewWithBarButtonItem:topItem.leftBarButtonItem];
        }
        
        // 自身添加 leftView.
        if (_leftView) {
            leftFrame = _leftView.frame;
            leftFrame.origin = CGPointMake(kButtonEdgeInsets.left, kButtonEdgeInsets.top);
            _leftView.frame = leftFrame;
            [self addSubview:_leftView];
        }
        
        //
        _rightView = [[self class] _viewWithBarButtonItem:topItem.rightBarButtonItem];
        
        if (_rightView) {
            _rightView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            rightFrame = _rightView.frame;
            rightFrame.origin.x = self.bounds.size.width-rightFrame.size.width - kButtonEdgeInsets.right;
            rightFrame.origin.y = kButtonEdgeInsets.top;
            _rightView.frame = rightFrame;
            [self addSubview:_rightView];
        }
        
        _centerView = topItem.titleView;
        
        if (!_centerView) {
            UILabel *titleLabel = [[UILabel alloc] init];
            titleLabel.text = topItem.title;
            titleLabel.textAlignment = UITextAlignmentCenter;
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.font = [UIFont boldSystemFontOfSize:14];
            _centerView = titleLabel;
        }
        
        CGRect centerFrame = CGRectZero;
        
        centerFrame.origin.y = kButtonEdgeInsets.top;
        centerFrame.size.height = kMaxButtonHeight;
        
        if (_leftView && _rightView) {
            centerFrame.origin.x = CGRectGetMaxX(leftFrame) + kButtonEdgeInsets.left;
            centerFrame.size.width = CGRectGetMinX(rightFrame) - kButtonEdgeInsets.right - centerFrame.origin.x;
        } else if (_leftView) {
            centerFrame.origin.x = CGRectGetMaxX(leftFrame) + kButtonEdgeInsets.left;
            centerFrame.size.width = CGRectGetWidth(self.bounds) - centerFrame.origin.x - CGRectGetWidth(leftFrame) - kButtonEdgeInsets.right - kButtonEdgeInsets.right;
        } else if (_rightView) {
            centerFrame.origin.x = CGRectGetWidth(rightFrame) + kButtonEdgeInsets.left + kButtonEdgeInsets.left;
            centerFrame.size.width = CGRectGetWidth(self.bounds) - centerFrame.origin.x - CGRectGetWidth(rightFrame) - kButtonEdgeInsets.right - kButtonEdgeInsets.right;
        } else {
            centerFrame.origin.x = kButtonEdgeInsets.left;
            centerFrame.size.width = CGRectGetWidth(self.bounds) - kButtonEdgeInsets.left - kButtonEdgeInsets.right;
        }
        
        _centerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _centerView.frame = centerFrame;
        [self insertSubview:_centerView atIndex:0];
        
        if (animated) {
            CGFloat moveCenterBy = self.bounds.size.width - ((_centerView)? _centerView.frame.origin.x : 0);
            CGFloat moveLeftBy = self.bounds.size.width * 0.33f;
            
            if (transition == _UINavigationBarTransitionPush) {
                moveLeftBy *= -1.f;
                moveCenterBy *= -1.f;
            }
            
            CGRect destinationLeftFrame = _leftView? _leftView.frame : CGRectZero;
            CGRect destinationCenterFrame = _centerView? _centerView.frame : CGRectZero;
            
            if (_leftView)      _leftView.frame = CGRectOffset(_leftView.frame, -moveLeftBy, 0);
            if (_centerView)    _centerView.frame = CGRectOffset(_centerView.frame, -moveCenterBy, 0);
            
            _leftView.alpha = 0;
            _rightView.alpha = 0;
            _centerView.alpha = 0;
            
            [UIView animateWithDuration:kAnimationDuration
                             animations:^(void) {
                _leftView.frame = destinationLeftFrame;
                _centerView.frame = destinationCenterFrame;
            }];
            
            [UIView animateWithDuration:kAnimationDuration * 0.8
                                  delay:kAnimationDuration * 0.2
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^(void) {
                _leftView.alpha = 1;
                _rightView.alpha = 1;
                _centerView.alpha = 1;
            }
                             completion:NULL];
        }
    } else {
        _leftView = _centerView = _rightView = nil;
    }
}

- (void)setTintColor:(UIColor *)newColor
{
    if (newColor != _tintColor) {
        _tintColor = newColor;
        [self setNeedsDisplay];
    }
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    if (![_itemStack isEqualToArray:items]) {
        [_itemStack removeAllObjects];
        [_itemStack addObjectsFromArray:items];
        [self updateViewsWithTransition:_UINavigationBarTransitionPush animated:animated];
    }
}

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:NO];
}


/**
 Pushes the given navigation item onto the navigation bar's stack and updates the UI.
 */
- (void)pushNavigationItem:(UINavigationItem *)item animated:(BOOL)animated
{
    BOOL shouldPush = YES;
    if (_delegateHas.shouldPushItem) {
        shouldPush = [_delegate navigationBar:self shouldPushItem:item];
    }
    
    if (shouldPush) {
        [_itemStack addObject:item];
        [self updateViewsWithTransition:_UINavigationBarTransitionPush animated:animated];
        
        if (_delegateHas.didPushItem) {
            [_delegate navigationBar:self didPushItem:item];
        }
    }
}

/**
 Pops the top item from the navigation bar's stack and updates the UI.
 */

- (UINavigationItem *)popNavigationItemAnimated:(BOOL)animated
{
    UINavigationItem *previousItem = self.topItem;
    
    if (previousItem) {
        BOOL shouldPop = YES;
        
        if (_delegateHas.shouldPopItem) {
            shouldPop = [_delegate navigationBar:self shouldPopItem:previousItem];
        }
        
        if (shouldPop) {
            [_itemStack removeObject:previousItem];
            [self updateViewsWithTransition:_UINavigationBarTransitionPop animated:animated];
            
            if (_delegateHas.didPopItem) {
                [_delegate navigationBar:self didPopItem:previousItem];
            }
            
            return previousItem;
        }
    }
    
    return nil;
}

- (void)_navigationItemDidChange:(NSNotification *)note
{
    if ([note object] == self.topItem || [note object] == self.backItem) {
        // this is going to remove & re-add all the item views. Not ideal, but simple enough that it's worth profiling.
        // next step is to add animation support-- that will require changing _setViewsWithTransition:animated:
        //  such that it won't perform any coordinate translations, only fade in/out
        
        [self updateViewsWithTransition:_UINavigationBarTransitionNone animated:NO];
    }
}

- (void)drawRect:(CGRect)rect
{
    const CGRect bounds = self.bounds;
    [self.tintColor setFill];
    UIRectFill(bounds);
}

// 固定的长宽
- (CGSize)sizeThatFits:(CGSize)size
{
    size.height = kBarHeight;
    return size;
}

@end
