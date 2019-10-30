#import "UIScroller.h"
#import "UITouch.h"
#import "UIBezierPath.h"
#import "UIColor.h"

static const BOOL _UIScrollerGutterEnabled = NO;
static const BOOL _UIScrollerJumpToSpotThatIsClicked = NO;	// _UIScrollerGutterEnabled must be YES for this to have any meaning
static const CGFloat _UIScrollerMinimumAlpha = 0;

@implementation UIScroller {
    CGFloat _dragOffset;
    BOOL _draggingKnob;
    BOOL _isVertical;
    CGPoint _lastTouchLocation;
    NSTimer *_holdTimer;
    NSTimer *_fadeTimer;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        self.opaque = NO;
        self.alpha = _UIScrollerMinimumAlpha;
        self.indicatorStyle = UIScrollViewIndicatorStyleDefault;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    _isVertical = (frame.size.height > frame.size.width);
    [super setFrame:frame];
}

// 消失动画.
- (void)_fadeOut
{
    [_fadeTimer invalidate];
    _fadeTimer = nil;
    
    [UIView animateWithDuration:0.33
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionTransitionNone | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^(void){self.alpha = _UIScrollerMinimumAlpha;}
                     completion:NULL];
}

// 注册消失动画
- (void)_fadeOutAfterDelay:(NSTimeInterval)time
{
    [_fadeTimer invalidate];
    _fadeTimer = [NSTimer scheduledTimerWithTimeInterval:time target:self selector:@selector(_fadeOut) userInfo:nil repeats:NO];
}

- (void)_fadeIn
{
    [_fadeTimer invalidate];
    _fadeTimer = nil;
    [UIView animateWithDuration:0.33
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionTransitionNone | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^(void) { self.alpha = 1; }
                     completion:NULL];
}

- (void)flash
{
    [self _fadeIn];
    
    if (!_alwaysVisible) {
        [self _fadeOutAfterDelay:1.5];
    }
}

- (void)quickFlash
{
    self.alpha = 1;
    
    if (!_alwaysVisible) {
        [self _fadeOutAfterDelay:0.5];
    }
}

- (void)setAlwaysVisible:(BOOL)v
{
    _alwaysVisible = v;
    
    if (_alwaysVisible) {
        [self _fadeIn];
    } else if (self.alpha > _UIScrollerMinimumAlpha && !_fadeTimer) {
        [self _fadeOut];
    }
}

- (void)setIndicatorStyle:(UIScrollViewIndicatorStyle)style
{
    _indicatorStyle = style;
    [self setNeedsDisplay];
}

- (CGFloat)knobSize
{
    const CGRect bounds = self.bounds;
    const CGFloat dimension = MAX(bounds.size.width, bounds.size.height);
    const CGFloat knobScale = MIN(1, (dimension / _contentSize));
    return MAX((dimension * knobScale), 50);
}

- (CGRect)knobRect
{
    const CGRect bounds = self.bounds;
    const CGFloat dimension = MAX(bounds.size.width, bounds.size.height);
    const CGFloat maxContentSize = MAX(1,(_contentSize-dimension));
    const CGFloat knobSize = [self knobSize];
    const CGFloat positionScale = MIN(1, (MIN(_contentOffset,maxContentSize) / maxContentSize));
    const CGFloat knobPosition = (dimension - knobSize) * positionScale;
    
    if (_isVertical) {
        return CGRectMake(bounds.origin.x, knobPosition, bounds.size.width, knobSize);
    } else {
        return CGRectMake(knobPosition, bounds.origin.y, knobSize, bounds.size.height);
    }
}

- (void)setContentOffset:(CGFloat)newOffset
{
    _contentOffset = MIN(MAX(0,newOffset),_contentSize);
    [self setNeedsDisplay];
}

- (void)setContentSize:(CGFloat)newContentSize
{
    _contentSize = newContentSize;
    [self setNeedsDisplay];
}

// 慢慢改变 contentOffset
- (void)setContentOffsetWithLastTouch
{
    const CGRect bounds = self.bounds;
    const CGFloat dimension = _isVertical? bounds.size.height : bounds.size.width;
    const CGFloat maxContentOffset = _contentSize - dimension;
    const CGFloat knobSize = [self knobSize];
    const CGFloat point = _isVertical? _lastTouchLocation.y : _lastTouchLocation.x;
    const CGFloat knobPosition = MIN(MAX(0, point-_dragOffset), (dimension-knobSize));
    const CGFloat contentOffset = (knobPosition / (dimension-knobSize)) * maxContentOffset;
    
    [self setContentOffset:contentOffset];
}

- (void)pageUp
{
    if (_isVertical) {
        [self setContentOffset:_contentOffset-self.bounds.size.height];
    } else {
        [self setContentOffset:_contentOffset-self.bounds.size.width];
    }
}

- (void)pageDown
{
    if (_isVertical) {
        [self setContentOffset:_contentOffset+self.bounds.size.height];
    } else {
        [self setContentOffset:_contentOffset+self.bounds.size.width];
    }
}

- (void)autoPageContent
{
    const CGRect knobRect = [self knobRect];
    
    if (!CGRectContainsPoint(knobRect, _lastTouchLocation) && CGRectContainsPoint(self.bounds, _lastTouchLocation)) {
        BOOL shouldPageUp;
        
        if (_isVertical) {
            shouldPageUp = (_lastTouchLocation.y < knobRect.origin.y);
        } else {
            shouldPageUp = (_lastTouchLocation.x < knobRect.origin.x);
        }
        
        if (shouldPageUp) {
            [self pageUp];
        } else {
            [self pageDown];
        }
        
        [_delegate _UIScroller:self contentOffsetDidChange:_contentOffset];
    }
}

- (void)startHoldPaging
{
    [_holdTimer invalidate];
    _holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(autoPageContent) userInfo:nil repeats:YES];
}

// 滑动条如何显示, 不是在里面有一个子 view, 而是画出来的.
- (void)drawRect:(CGRect)rect
{
    CGRect knobRect = [self knobRect];
    
    if (_isVertical) {
        knobRect.origin.y += 2;
        knobRect.size.height -= 4;
        knobRect.origin.x += 1;
        knobRect.size.width -= 3;
    } else {
        knobRect.origin.y += 1;
        knobRect.size.height -= 3;
        knobRect.origin.x += 2;
        knobRect.size.width -= 4;
    }
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:knobRect cornerRadius:4];
    
    if (_indicatorStyle == UIScrollViewIndicatorStyleBlack) {
        [[[UIColor blackColor] colorWithAlphaComponent:0.5] setFill];
    } else if (_indicatorStyle == UIScrollViewIndicatorStyleWhite) {
        [[[UIColor whiteColor] colorWithAlphaComponent:0.5] setFill];
    } else {
        [[[UIColor blackColor] colorWithAlphaComponent:0.5] setFill];
        [[[UIColor whiteColor] colorWithAlphaComponent:0.3] setStroke];
        [path setLineWidth:1.8];
        [path stroke];
    }
    
    [path fill];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _lastTouchLocation = [[touches anyObject] locationInView:self];
    const CGRect knobRect = [self knobRect];
    
    if (CGRectContainsPoint(knobRect,_lastTouchLocation)) { // 如果, 点击点在滑动块上.
        if (_isVertical) {
            _dragOffset = _lastTouchLocation.y - knobRect.origin.y;
        } else {
            _dragOffset = _lastTouchLocation.x - knobRect.origin.x;
        }
        _draggingKnob = YES;
        [_delegate _UIScrollerDidBeginDragging:self withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    _lastTouchLocation = [[touches anyObject] locationInView:self];
    
    if (_draggingKnob) {
        [self setContentOffsetWithLastTouch];
        [_delegate _UIScroller:self contentOffsetDidChange:_contentOffset];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_draggingKnob) {
        _draggingKnob = NO;
        [_delegate _UIScrollerDidEndDragging:self withEvent:event];
    } else if (_holdTimer) {
        [_delegate _UIScrollerDidEndDragging:self withEvent:event];
        [_holdTimer invalidate];
        _holdTimer = nil;
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hit = [super hitTest:point withEvent:event];
    
    // if the gutter is disabled, then we pretend the view is invisible to events if the user clicks in the gutter
    // otherwise the scroller would capture those clicks and things wouldn't work as expected.
    if (hit == self && !_UIScrollerGutterEnabled && !CGRectContainsPoint([self knobRect],point)) {
        hit = nil;
    }
    
    return hit;
}

@end
