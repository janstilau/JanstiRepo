#import "UIScrollView.h"
#import "UIScroller.h"
#import "UITouch.h"
#import "UIResponderAppKitIntegration.h"
#import "UIScrollViewAnimationScroll.h"
#import "UIScrollViewAnimationDeceleration.h"
#import "UIPanGestureRecognizer.h"
#import <QuartzCore/QuartzCore.h>

static const NSTimeInterval UIScrollViewAnimationDuration = 0.33;
static const NSTimeInterval UIScrollViewQuickAnimationDuration = 0.22;
static const NSUInteger UIScrollViewScrollAnimationFramesPerSecond = 60;

const float UIScrollViewDecelerationRateNormal = 0.998;
const float UIScrollViewDecelerationRateFast = 0.99;

@interface UIScrollView () <_UIScrollerDelegate>
@end

@implementation UIScrollView {
    UIScroller *_verticalScroller;
    UIScroller *_horizontalScroller;
    
    UIScrollViewAnimation *_scrollAnimation;
    NSTimer *_scrollTimer;
    
    struct {
        unsigned scrollViewDidScroll : 1;
        unsigned scrollViewWillBeginDragging : 1;
        unsigned scrollViewDidEndDragging : 1;
        unsigned viewForZoomingInScrollView : 1;
        unsigned scrollViewWillBeginZooming : 1;
        unsigned scrollViewDidEndZooming : 1;
        unsigned scrollViewDidZoom : 1;
        unsigned scrollViewDidEndScrollingAnimation : 1;
        unsigned scrollViewWillBeginDecelerating : 1;
        unsigned scrollViewDidEndDecelerating : 1;
    } _delegateCan; // _delegateCan 是根据 delegate 的能力保存的, 也就是不用每次调用 respond 方法, 相当于对于 delegate 进行了缓存.
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _contentOffset = CGPointZero;
        _contentSize = CGSizeZero;
        _contentInset = UIEdgeInsetsZero;
        _scrollIndicatorInsets = UIEdgeInsetsZero;
        _showsVerticalScrollIndicator = YES;
        _showsHorizontalScrollIndicator = YES;
        _maximumZoomScale = 1;
        _minimumZoomScale = 1;
        _scrollsToTop = YES;
        _indicatorStyle = UIScrollViewIndicatorStyleDefault;
        _delaysContentTouches = YES;
        _canCancelContentTouches = YES;
        _pagingEnabled = NO;
        _bouncesZoom = NO;
        _zooming = NO;
        _alwaysBounceVertical = NO;
        _alwaysBounceHorizontal = NO;
        _bounces = YES;
        _decelerationRate = UIScrollViewDecelerationRateNormal;
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_gestureDidChange:)];
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _verticalScroller = [[UIScroller alloc] init];
        _verticalScroller.delegate = self;
        [self addSubview:_verticalScroller];
        
        _horizontalScroller = [[UIScroller alloc] init];
        _horizontalScroller.delegate = self;
        [self addSubview:_horizontalScroller];
        
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setDelegate:(id)newDelegate
{
    // 在进行 delegate 的设置的时候, 对 delegate 的相应能力进行了管理.
    _delegate = newDelegate;
    _delegateCan.scrollViewDidScroll = [_delegate respondsToSelector:@selector(scrollViewDidScroll:)];
    _delegateCan.scrollViewWillBeginDragging = [_delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _delegateCan.scrollViewDidEndDragging = [_delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
    _delegateCan.viewForZoomingInScrollView = [_delegate respondsToSelector:@selector(viewForZoomingInScrollView:)];
    _delegateCan.scrollViewWillBeginZooming = [_delegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)];
    _delegateCan.scrollViewDidEndZooming = [_delegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)];
    _delegateCan.scrollViewDidZoom = [_delegate respondsToSelector:@selector(scrollViewDidZoom:)];
    _delegateCan.scrollViewDidEndScrollingAnimation = [_delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)];
    _delegateCan.scrollViewWillBeginDecelerating = [_delegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)];
    _delegateCan.scrollViewDidEndDecelerating = [_delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)];
}

- (UIView *)_zoomingView
{
    return (_delegateCan.viewForZoomingInScrollView)? [_delegate viewForZoomingInScrollView:self] : nil;
}

- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style
{
    _indicatorStyle = style;
    _horizontalScroller.indicatorStyle = style;
    _verticalScroller.indicatorStyle = style;
}

- (void)setShowsHorizontalScrollIndicator:(BOOL)show
{
    _showsHorizontalScrollIndicator = show;
    [self setNeedsLayout];
}

- (void)setShowsVerticalScrollIndicator:(BOOL)show
{
    _showsVerticalScrollIndicator = show;
    [self setNeedsLayout];
}

// 属性验证, 范围验证.
- (BOOL)_canScrollHorizontal
{
    return self.scrollEnabled && (_contentSize.width > self.bounds.size.width);
}

// 属性验证, 范围验证.
- (BOOL)_canScrollVertical
{
    return self.scrollEnabled && (_contentSize.height > self.bounds.size.height);
}

// 更新滚动条的范围和具体的 offset 位置.
- (void)_updateScrollers
{
    _verticalScroller.contentSize = _contentSize.height;
    _verticalScroller.contentOffset = _contentOffset.y;
    _horizontalScroller.contentSize = _contentSize.width;
    _horizontalScroller.contentOffset = _contentOffset.x;
    
    _verticalScroller.hidden = !self._canScrollVertical;
    _horizontalScroller.hidden = !self._canScrollHorizontal;
}

// 所以, scrollView 的 scrollEnable 就是手势可不可以接受事件.
- (void)setScrollEnabled:(BOOL)enabled
{
    self.panGestureRecognizer.enabled = enabled;
    [self _updateScrollers];
    [self setNeedsLayout];
}

- (BOOL)isScrollEnabled
{
    return self.panGestureRecognizer.enabled;
}

- (void)_cancelScrollAnimation
{
    [_scrollTimer invalidate];
    _scrollTimer = nil;
    _scrollAnimation = nil;
    if (_delegateCan.scrollViewDidEndScrollingAnimation) {
        [_delegate scrollViewDidEndScrollingAnimation:self];
    }
    if (_decelerating) {
        _horizontalScroller.alwaysVisible = NO;
        _verticalScroller.alwaysVisible = NO;
        _decelerating = NO;
        if (_delegateCan.scrollViewDidEndDecelerating) {
            [_delegate scrollViewDidEndDecelerating:self];
        }
    }
}


// 这里, 应该是根据 当前的 animation 的值, 进行 scrollView 的 contentOffset 的更改
// animate 中会有 scrollView 的变化, 这里作者的 API 取名有点问题.
- (void)_updateScrollAnimation
{
    if ([_scrollAnimation animate]) {
        [self _cancelScrollAnimation];
    }
}

// 如果滚动需要减速停止的效果, 就加入一个 animation, 其实就是一个定时不断改变 scrollView 的位置. 当需要的时候, 比如重新开始滚动的时候, 需要将这个动画和相应的定时器移除.
- (void)_setScrollAnimation:(UIScrollViewAnimation *)animation
{
    [self _cancelScrollAnimation]; // 首先取消原来的动画.
    
    _scrollAnimation = animation;
    
    if (!_scrollTimer) {
        _scrollTimer = [NSTimer scheduledTimerWithTimeInterval:1/(NSTimeInterval)UIScrollViewScrollAnimationFramesPerSecond
                                                        target:self
                                                      selector:@selector(_updateScrollAnimation)
                                                      userInfo:nil repeats:YES];
    }
}

// 限制, offset 的范围, 在自己的可滚动的范围之内.
- (CGPoint)_confinedContentOffset:(CGPoint)targetOffset
{
    const CGRect scrollerBounds = UIEdgeInsetsInsetRect(self.bounds, _contentInset);
    
    if ((_contentSize.width-targetOffset.x) < scrollerBounds.size.width) {
        targetOffset.x = (_contentSize.width - scrollerBounds.size.width);
    }
    
    if ((_contentSize.height-targetOffset.y) < scrollerBounds.size.height) {
        targetOffset.y = (_contentSize.height - scrollerBounds.size.height);
    }
    
    targetOffset.x = MAX(targetOffset.x,0);
    targetOffset.y = MAX(targetOffset.y,0);
    
    if (_contentSize.width <= scrollerBounds.size.width) {
        targetOffset.x = 0;
    }
    
    if (_contentSize.height <= scrollerBounds.size.height) {
        targetOffset.y = 0;
    }
    
    return targetOffset;
}

- (void)_setRestrainedContentOffset:(CGPoint)offset
{
    const CGPoint confinedOffset = [self _confinedContentOffset:offset];
    const CGRect scrollerBounds = UIEdgeInsetsInsetRect(self.bounds, _contentInset);
    
    if (!self.alwaysBounceHorizontal && _contentSize.width <= scrollerBounds.size.width) {
        offset.x = confinedOffset.x;
    }
    
    if (!self.alwaysBounceVertical && _contentSize.height <= scrollerBounds.size.height) {
        offset.y = confinedOffset.y;
    }
    
    self.contentOffset = offset;
}

- (void)_confineContent
{
    self.contentOffset = [self _confinedContentOffset:_contentOffset];
}


// layoutSubview 仅仅管理两个滚动条的位置.
- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGRect bounds = self.bounds;
    const CGFloat scrollerSize = UIScrollerWidthForBoundsSize(bounds.size);
    _verticalScroller.frame = CGRectMake(bounds.origin.x+bounds.size.width-scrollerSize-_scrollIndicatorInsets.right,bounds.origin.y+_scrollIndicatorInsets.top,scrollerSize,bounds.size.height-_scrollIndicatorInsets.top-_scrollIndicatorInsets.bottom);
    _horizontalScroller.frame = CGRectMake(bounds.origin.x+_scrollIndicatorInsets.left,bounds.origin.y+bounds.size.height-scrollerSize-_scrollIndicatorInsets.bottom,bounds.size.width-_scrollIndicatorInsets.left-_scrollIndicatorInsets.right,scrollerSize);
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self _confineContent];
}

// 每次进行子 View 的管理, 都要把滚动条往上提.
- (void)_bringScrollersToFront
{
    [super bringSubviewToFront:_horizontalScroller];
    [super bringSubviewToFront:_verticalScroller];
}

- (void)addSubview:(UIView *)subview
{
    [super addSubview:subview];
    [self _bringScrollersToFront];
}

- (void)bringSubviewToFront:(UIView *)subview
{
    [super bringSubviewToFront:subview];
    [self _bringScrollersToFront];
}

- (void)insertSubview:(UIView *)subview atIndex:(NSInteger)index
{
    [super insertSubview:subview atIndex:index];
    [self _bringScrollersToFront];
}

// 这里, 没有明确的说明, 为什么 bounds 的改变可以造成 scrollView 的改变.
- (void)_updateBounds
{
    CGRect bounds = self.bounds;
    bounds.origin.x = _contentOffset.x - _contentInset.left;
    bounds.origin.y = _contentOffset.y - _contentInset.top;
    self.bounds = bounds;
    
    [self _updateScrollers];
    [self setNeedsLayout];
}

- (void)setContentOffset:(CGPoint)theOffset animated:(BOOL)animated
{
    if (animated) {
        UIScrollViewAnimationScroll *animation = nil;
        
        if ([_scrollAnimation isKindOfClass:[UIScrollViewAnimationScroll class]]) {
            animation = (UIScrollViewAnimationScroll *)_scrollAnimation;
        }
        
        if (!animation || !CGPointEqualToPoint(theOffset, animation.endContentOffset)) {
            [self _setScrollAnimation:[[UIScrollViewAnimationScroll alloc] initWithScrollView:self
                                                                            fromContentOffset:self.contentOffset
                                                                              toContentOffset:theOffset
                                                                                     duration:UIScrollViewAnimationDuration
                                                                                        curve:UIScrollViewAnimationScrollCurveLinear]];
        }
    } else {
        _contentOffset.x = roundf(theOffset.x);
        _contentOffset.y = roundf(theOffset.y);
        [self _updateBounds];
        // 在这里, 进行了 scrollViewDidScroll 的调用.
        if (_delegateCan.scrollViewDidScroll) {
            [_delegate scrollViewDidScroll:self];
        }
    }
}

- (void)setContentOffset:(CGPoint)theOffset
{
    [self setContentOffset:theOffset animated:NO];
}

// contentInset, 间接影响了 offset 的取值.
- (void)setContentInset:(UIEdgeInsets)contentInset
{
    if (!UIEdgeInsetsEqualToEdgeInsets(contentInset, _contentInset)) {
        const CGFloat x = contentInset.left - _contentInset.left;
        const CGFloat y = contentInset.top - _contentInset.top;
        
        _contentInset = contentInset;
        _contentOffset.x -= x;
        _contentOffset.y -= y;
        
        [self _updateBounds];
    }
}

- (void)setContentSize:(CGSize)newSize
{
    if (!CGSizeEqualToSize(newSize, _contentSize)) {
        _contentSize = newSize;
        [self _confineContent];
    }
}

// 滚动条其实是占据了下方, 右方的所有区域, 只不过, 根据 contentOffset 更新小黑块的位置, 这在 WM的 progressView 中进行了体现.
- (void)flashScrollIndicators
{
    [_horizontalScroller flash];
    [_verticalScroller flash];
}

- (void)_quickFlashScrollIndicators
{
    [_horizontalScroller quickFlash];
    [_verticalScroller quickFlash];
}

- (BOOL)isTracking
{
    return NO;
}

- (UIScrollViewAnimation *)_pageSnapAnimation
{
    const CGSize pageSize = self.bounds.size;
    const CGSize numberOfWholePages = CGSizeMake(floorf(_contentSize.width/pageSize.width), floorf(_contentSize.height/pageSize.height));
    const CGSize currentRawPage = CGSizeMake(_contentOffset.x/pageSize.width, _contentOffset.y/pageSize.height);
    const CGSize currentPage = CGSizeMake(floorf(currentRawPage.width), floorf(currentRawPage.height));
    const CGSize currentPagePercentage = CGSizeMake(1-(currentRawPage.width-currentPage.width), 1-(currentRawPage.height-currentPage.height));
    
    CGPoint finalContentOffset = CGPointZero;
    
    // if currentPagePercentage is less than 50%, then go to the next page (if any), otherwise snap to the current page
    
    if (currentPagePercentage.width < 0.5 && (currentPage.width+1) < numberOfWholePages.width) {
        finalContentOffset.x = pageSize.width * (currentPage.width + 1);
    } else {
        finalContentOffset.x = pageSize.width * currentPage.width;
    }
    
    if (currentPagePercentage.height < 0.5 && (currentPage.height+1) < numberOfWholePages.height) {
        finalContentOffset.y = pageSize.height * (currentPage.height + 1);
    } else {
        finalContentOffset.y = pageSize.height * currentPage.height;
    }
    
    // quickly animate the snap (if necessary)
    if (!CGPointEqualToPoint(finalContentOffset, _contentOffset)) {
        return [[UIScrollViewAnimationScroll alloc] initWithScrollView:self
                                                     fromContentOffset:_contentOffset
                                                       toContentOffset:finalContentOffset
                                                              duration:UIScrollViewQuickAnimationDuration
                                                                 curve:UIScrollViewAnimationScrollCurveQuadraticEaseOut];
    } else {
        return nil;
    }
}

- (UIScrollViewAnimation *)_decelerationAnimationWithVelocity:(CGPoint)velocity
{
    const CGPoint confinedOffset = [self _confinedContentOffset:_contentOffset];
    
    // if we've pulled up the content outside it's bounds, we don't want to register any flick momentum there and instead just
    // have the animation pull the content back into place immediately.
    if (confinedOffset.x != _contentOffset.x) {
        velocity.x = 0;
    }
    if (confinedOffset.y != _contentOffset.y) {
        velocity.y = 0;
    }
    
    if (!CGPointEqualToPoint(velocity, CGPointZero) || !CGPointEqualToPoint(confinedOffset, _contentOffset)) {
        return [[UIScrollViewAnimationDeceleration alloc] initWithScrollView:self
                                                                    velocity:velocity];
    } else {
        return nil;
    }
}

// _dragging 这个状态, 是根据 panGesture 的手势不同阶段, 进行值的改变.
- (void)_beginDragging
{
    if (!_dragging) {
        _dragging = YES;
        _horizontalScroller.alwaysVisible = YES;
        _verticalScroller.alwaysVisible = YES;
        [self _cancelScrollAnimation];
        if (_delegateCan.scrollViewWillBeginDragging) {
            [_delegate scrollViewWillBeginDragging:self];
        }
    }
}

- (void)_endDraggingWithDecelerationVelocity:(CGPoint)velocity
{
    if (_dragging) {
        _dragging = NO;
        // 渐渐取消演示的动画, 封装到了各个 animation 的子类里面.
        UIScrollViewAnimation *decelerationAnimation = _pagingEnabled? [self _pageSnapAnimation] : [self _decelerationAnimationWithVelocity:velocity];
        
        if (_delegateCan.scrollViewDidEndDragging) {
            [_delegate scrollViewDidEndDragging:self willDecelerate:(decelerationAnimation != nil)];
        }
        
        if (decelerationAnimation) {
            [self _setScrollAnimation:decelerationAnimation];
            
            _horizontalScroller.alwaysVisible = YES;
            _verticalScroller.alwaysVisible = YES;
            _decelerating = YES;
            
            if (_delegateCan.scrollViewWillBeginDecelerating) {
                [_delegate scrollViewWillBeginDecelerating:self];
            }
        } else {
            _horizontalScroller.alwaysVisible = NO;
            _verticalScroller.alwaysVisible = NO;
            [self _confineContent];
        }
    }
}

- (void)_dragBy:(CGPoint)delta
{
    if (_dragging) {
        _horizontalScroller.alwaysVisible = YES;
        _verticalScroller.alwaysVisible = YES;
        
        const CGPoint originalOffset = self.contentOffset;
        
        CGPoint proposedOffset = originalOffset;
        proposedOffset.x += delta.x;
        proposedOffset.y += delta.y;
        
        const CGPoint confinedOffset = [self _confinedContentOffset:proposedOffset];
        
        if (self.bounces) {
            BOOL shouldHorizontalBounce = (fabs(proposedOffset.x - confinedOffset.x) > 0);
            BOOL shouldVerticalBounce = (fabs(proposedOffset.y - confinedOffset.y) > 0);
            
            if (shouldHorizontalBounce) {
                proposedOffset.x = originalOffset.x + (0.055 * delta.x);
            }
            
            if (shouldVerticalBounce) {
                proposedOffset.y = originalOffset.y + (0.055 * delta.y);
            }
            
            [self _setRestrainedContentOffset:proposedOffset];
        } else {
            // 如果没有弹性, 那么直接设置 offset.
            [self setContentOffset:confinedOffset];
        }
    }
}

- (void)_gestureDidChange:(UIGestureRecognizer *)gesture
{
    if (_panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self _beginDragging];
    } else if (_panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        [self _dragBy:[_panGestureRecognizer translationInView:self]];
        [_panGestureRecognizer setTranslation:CGPointZero inView:self];
    } else if (_panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self _endDraggingWithDecelerationVelocity:[_panGestureRecognizer velocityInView:self]];
    }
}

// 滚动条的代理方法.
- (void)_UIScrollerDidBeginDragging:(UIScroller *)scroller withEvent:(UIEvent *)event
{
    [self _beginDragging];
}

- (void)_UIScroller:(UIScroller *)scroller contentOffsetDidChange:(CGFloat)newOffset
{
    if (scroller == _verticalScroller) {
        [self setContentOffset:CGPointMake(self.contentOffset.x,newOffset) animated:NO];
    } else if (scroller == _horizontalScroller) {
        [self setContentOffset:CGPointMake(newOffset,self.contentOffset.y) animated:NO];
    }
}

- (void)_UIScrollerDidEndDragging:(UIScroller *)scroller withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    const CGPoint point = [touch locationInView:self];
    
    if (!CGRectContainsPoint(scroller.frame,point)) {
        scroller.alwaysVisible = NO;
    }
    
    [self _endDraggingWithDecelerationVelocity:CGPointZero];
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated
{
    const CGRect contentRect = CGRectMake(0,0,_contentSize.width, _contentSize.height);
    const CGRect visibleRect = self.bounds;
    CGRect goalRect = CGRectIntersection(rect, contentRect);
    
    if (!CGRectIsNull(goalRect) && !CGRectContainsRect(visibleRect, goalRect)) {
        
        // clamp the goal rect to the largest possible size for it given the visible space available
        // this causes it to prefer the top-left of the rect if the rect is too big
        goalRect.size.width = MIN(goalRect.size.width, visibleRect.size.width);
        goalRect.size.height = MIN(goalRect.size.height, visibleRect.size.height);
        
        CGPoint offset = self.contentOffset;
        
        if (CGRectGetMaxY(goalRect) > CGRectGetMaxY(visibleRect)) {
            offset.y += CGRectGetMaxY(goalRect) - CGRectGetMaxY(visibleRect);
        } else if (CGRectGetMinY(goalRect) < CGRectGetMinY(visibleRect)) {
            offset.y += CGRectGetMinY(goalRect) - CGRectGetMinY(visibleRect);
        }
        
        if (CGRectGetMaxX(goalRect) > CGRectGetMaxX(visibleRect)) {
            offset.x += CGRectGetMaxX(goalRect) - CGRectGetMaxX(visibleRect);
        } else if (CGRectGetMinX(goalRect) < CGRectGetMinX(visibleRect)) {
            offset.x += CGRectGetMinX(goalRect) - CGRectGetMinX(visibleRect);
        }
        
        [self setContentOffset:offset animated:animated];
    }
}

- (BOOL)isZoomBouncing
{
    return NO;
}

- (float)zoomScale
{
    UIView *zoomingView = [self _zoomingView];
    
    // it seems weird to return the "a" component of the transform for this, but after some messing around with the real UIKit, I'm
    // reasonably certain that's how it is doing it.
    return zoomingView? zoomingView.transform.a : 1.f;
}

// 在这里表现的很清楚, 当进行 zoom 的时候, contentSize 就是根据 zoomView 的frame 进行的设置.
- (void)setZoomScale:(float)scale animated:(BOOL)animated
{
    UIView *zoomingView = [self _zoomingView];
    scale = MIN(MAX(scale, _minimumZoomScale), _maximumZoomScale);
    
    if (zoomingView && self.zoomScale != scale) {
        [UIView animateWithDuration:animated? UIScrollViewAnimationDuration : 0
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void) {
            zoomingView.transform = CGAffineTransformMakeScale(scale, scale);
            const CGSize size = zoomingView.frame.size;
            zoomingView.layer.position = CGPointMake(size.width/2.f, size.height/2.f);
            self.contentSize = size;
        }
                         completion:NULL];
    }
}

- (void)setZoomScale:(float)scale
{
    [self setZoomScale:scale animated:NO];
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated
{
}

// after some experimentation, it seems UIScrollView blocks or captures the touch events that fall through and
// I'm not entirely sure why, but something is certainly going on there so I'm replicating that here. since I
// suspect it's just stopping everything from going through, I'm also capturing and ignoring some of the
// mouse-related responder events added by Chameleon rather than passing them along the responder chain, too.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
}

@end
