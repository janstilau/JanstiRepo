#import "UIView+UIPrivate.h"
#import "UIWindow.h"
#import "UIGraphics.h"
#import "UIViewLayoutManager.h"
#import "UIViewAnimationGroup.h"
#import "UIViewController.h"
#import "UIAppearanceInstance.h"
#import "UIGestureRecognizer+UIPrivate.h"
#import "UIApplicationAppKitIntegration.h"
#import "UIScreen.h"
#import "UIColor+UIPrivate.h"
#import "UIColorRep.h"
#import <QuartzCore/CALayer.h>

NSString *const UIViewFrameDidChangeNotification = @"UIViewFrameDidChangeNotification";
NSString *const UIViewBoundsDidChangeNotification = @"UIViewBoundsDidChangeNotification";
NSString *const UIViewDidMoveToSuperviewNotification = @"UIViewDidMoveToSuperviewNotification";
NSString *const UIViewHiddenDidChangeNotification = @"UIViewHiddenDidChangeNotification";

static NSMutableArray *_animationGroupStack;
static BOOL _animationsEnabled = YES;

@implementation UIView {
    __unsafe_unretained UIView *_superview;
    __unsafe_unretained UIViewController *_viewController;
    NSMutableSet *_subviews; // 无序????
    BOOL _implementsDrawRect;
    NSMutableSet *_gestureRecognizers;
}

+ (void)initialize
{
    if (self == [UIView class]) {
        _animationGroupStack = [[NSMutableArray alloc] init];
    }
}

// 一个切口, 给程序员自定义自己 Layer 的权力.
+ (Class)layerClass
{
    return [CALayer class];
}

+ (BOOL)_instanceImplementsDrawRect
{
    return [UIView instanceMethodForSelector:@selector(drawRect:)] != [self instanceMethodForSelector:@selector(drawRect:)];
}

- (id)init
{
    return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)theFrame
{
    if ((self=[super init])) {
        _implementsDrawRect = [[self class] _instanceImplementsDrawRect];
        _clearsContextBeforeDrawing = YES;
        _autoresizesSubviews = YES;
        _userInteractionEnabled = YES;
        _subviews = [[NSMutableSet alloc] init];
        _gestureRecognizers = [[NSMutableSet alloc] init];

        _layer = [[[[self class] layerClass] alloc] init];
        _layer.delegate = self;
        _layer.layoutManager = [UIViewLayoutManager layoutManager];

        self.contentMode = UIViewContentModeScaleToFill;
        self.contentScaleFactor = 0;
        self.frame = theFrame;
        self.alpha = 1;
        self.opaque = YES;
        [self setNeedsDisplay];
    }
    return self;
}

// 记录了自己所属的 viewController
- (void)_setViewController:(UIViewController *)theViewController
{
    _viewController = theViewController;
}

- (UIViewController *)_viewController
{
    return _viewController;
}

- (UIWindow *)window
{
    return _superview.window;
}

// 返回下一个响应者.
- (UIResponder *)nextResponder
{
    return (UIResponder *)[self _viewController] ?: (UIResponder *)_superview;
}

// 这里, 没有返回真正的自己的容器对象, 而是新组建了一个容器返回了.
- (NSArray *)subviews
{
    NSArray *sublayers = _layer.sublayers;
    NSMutableArray *subviews = [NSMutableArray arrayWithCapacity:[sublayers count]];

    for (CALayer *layer in sublayers) {
        id potentialView = [layer delegate];
        if ([_subviews containsObject:potentialView]) {
            [subviews addObject:potentialView];
        }
    }
    
    return subviews;
}

// 由于 VC 可能不是通过 transitionFromViewController 进行变化. 这里, view 会在添加到 windwon 的时候, 主动调用一次.

- (void)_willMoveFromWindow:(UIWindow *)fromWindow toWindow:(UIWindow *)toWindow
{
    if (fromWindow != toWindow) {
        if ([self isFirstResponder]) {
            [self resignFirstResponder];
        }
        
        [self willMoveToWindow:toWindow];

        for (UIView *subview in self.subviews) { // 通知自己的子 View.
            [subview _willMoveFromWindow:fromWindow toWindow:toWindow];
        }
        
        [[self _viewController] beginAppearanceTransition:(toWindow != nil) animated:NO];
        // 在这里, 会通知 vc 的 ViewWillAppear 和 ViewDidAppear.
    }
}

- (void)_didMoveToScreen
{
    [self setNeedsDisplay];
    for (UIView *subview in self.subviews) {
        [subview _didMoveToScreen];
    }
}

- (void)_didMoveFromWindow:(UIWindow *)fromWindow toWindow:(UIWindow *)toWindow
{
    if (fromWindow != toWindow) {
        [self didMoveToWindow];

        for (UIView *subview in self.subviews) {
            [subview _didMoveFromWindow:fromWindow toWindow:toWindow];
        }
        
        UIViewController *controller = [self _viewController];

        if (controller) {
            if ([[self class] _isAnimating]) {
                void (^completionBlock)(BOOL) = [[self class] _animationCompletionBlock];

                [[self class] _setAnimationCompletionBlock:^(BOOL finished) {
                    [controller endAppearanceTransition];
                    
                    if (completionBlock) {
                        completionBlock(finished);
                    }
                }];
            } else {
                [controller performSelector:@selector(endAppearanceTransition) withObject:nil afterDelay:0];
            }
        }
    }
}

- (void)addSubview:(UIView *)subview
{
    if (subview && subview.superview != self) {
        UIWindow *oldWindow = subview.window;
        UIWindow *newWindow = self.window;
        
        [subview _willMoveFromWindow:oldWindow toWindow:newWindow];
        [subview willMoveToSuperview:self]; // 暴露给程序员自定义的接口.

        if (subview.superview) { // 清楚原来的 superView 相关逻辑.
            [subview.layer removeFromSuperlayer];
            [subview.superview->_subviews removeObject:subview];
        }
        
        [subview willChangeValueForKey:@"superview"];
        [_subviews addObject:subview];
        subview->_superview = self;
        [_layer addSublayer:subview.layer];
        [subview didChangeValueForKey:@"superview"];

        if (oldWindow.screen != newWindow.screen) {
            [subview _didMoveToScreen];
        }
        
        [subview _didMoveFromWindow:oldWindow toWindow:newWindow];
        [subview didMoveToSuperview];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:UIViewDidMoveToSuperviewNotification object:subview];

        [self didAddSubview:subview];
    }
}

- (void)insertSubview:(UIView *)subview atIndex:(NSInteger)index
{
    [self addSubview:subview];
    [_layer insertSublayer:subview.layer atIndex:index];
}

- (void)insertSubview:(UIView *)subview belowSubview:(UIView *)below
{
    [self addSubview:subview];
    [_layer insertSublayer:subview.layer below:below.layer];
}

- (void)insertSubview:(UIView *)subview aboveSubview:(UIView *)above
{
    [self addSubview:subview];
    [_layer insertSublayer:subview.layer above:above.layer];
}

- (void)bringSubviewToFront:(UIView *)subview
{
    if (subview.superview == self) {
        [_layer insertSublayer:subview.layer above:[[_layer sublayers] lastObject]];
    }
}

- (void)sendSubviewToBack:(UIView *)subview
{
    if (subview.superview == self) {
        [_layer insertSublayer:subview.layer atIndex:0];
    }
}

- (void)_abortGestureRecognizers
{
    // note - the real UIKit supports multitouch so it only really interruptes the current touch
    // and not all of them, but this is easier for now since we don't support that anyway.
    UIApplicationInterruptTouchesInView(self);
}

- (void)_removeFromDeallocatedSuperview
{
    _superview = nil;
    [self _abortGestureRecognizers];
}

- (void)removeFromSuperview
{
    if (_superview) {
        UIWindow *oldWindow = self.window;

        [_superview willRemoveSubview:self];
        [self _willMoveFromWindow:oldWindow toWindow:nil];
        [self willMoveToSuperview:nil];
        
        [self willChangeValueForKey:@"superview"];
        [_layer removeFromSuperlayer];
        [_superview->_subviews removeObject:self];
        _superview = nil;
        [self didChangeValueForKey:@"superview"];

        [self _abortGestureRecognizers];

        [[NSNotificationCenter defaultCenter] postNotificationName:UIViewDidMoveToSuperviewNotification object:self];

        [self _didMoveFromWindow:oldWindow toWindow:nil];
        [self didMoveToSuperview];
    }
}

// 自定义行为的切口.
- (void)didAddSubview:(UIView *)subview
{
}

- (void)didMoveToSuperview
{
}

- (void)didMoveToWindow
{
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
}

- (void)willRemoveSubview:(UIView *)subview
{
}


// 简简单单的递归调用.
- (CGPoint)convertPoint:(CGPoint)toConvert fromView:(UIView *)fromView
{
    // NOTE: this is a lot more complex than it needs to be - I just noticed the docs say this method requires fromView and self to
    // belong to the same UIWindow! arg! leaving this for now because, well, it's neat.. but also I'm too tired to really ponder
    // all the implications of a change to something so "low level".
    
    if (fromView) {
        // If the screens are the same, then we know they share a common parent CALayer, so we can convert directly with the layer's
        // conversion method. If not, though, we need to do something a bit more complicated.
        if (fromView && (self.window.screen == fromView.window.screen)) {
            return [fromView.layer convertPoint:toConvert toLayer:self.layer];
        } else {
            // Convert coordinate to fromView's window base coordinates.
            toConvert = [fromView.layer convertPoint:toConvert toLayer:fromView.window.layer];
            
            // Now convert from fromView's window to our own window.
            toConvert = [fromView.window convertPoint:toConvert toWindow:self.window];
        }
    }

    // Convert from our window coordinate space into our own coordinate space.
    return [self.window.layer convertPoint:toConvert toLayer:self.layer];
}

- (CGPoint)convertPoint:(CGPoint)toConvert toView:(UIView *)toView
{
    // NOTE: this is a lot more complex than it needs to be - I just noticed the docs say this method requires toView and self to
    // belong to the same UIWindow! arg! leaving this for now because, well, it's neat.. but also I'm too tired to really ponder
    // all the implications of a change to something so "low level".
    
    // See note in convertPoint:fromView: for some explaination about why this is done... :/
    if (toView && (self.window.screen == toView.window.screen)) {
        return [self.layer convertPoint:toConvert toLayer:toView.layer];
    } else {
        // Convert to our window's coordinate space.
        toConvert = [self.layer convertPoint:toConvert toLayer:self.window.layer];
        
        if (toView) {
            // Convert from one window's coordinate space to another.
            toConvert = [self.window convertPoint:toConvert toWindow:toView.window];
            
            // Convert from toView's window down to toView's coordinate space.
            toConvert = [toView.window.layer convertPoint:toConvert toLayer:toView.layer];
        }
        
        return toConvert;
    }
}

- (CGRect)convertRect:(CGRect)toConvert fromView:(UIView *)fromView
{
    CGPoint origin = [self convertPoint:CGPointMake(CGRectGetMinX(toConvert),CGRectGetMinY(toConvert)) fromView:fromView];
    CGPoint bottom = [self convertPoint:CGPointMake(CGRectGetMaxX(toConvert),CGRectGetMaxY(toConvert)) fromView:fromView];
    return CGRectMake(origin.x, origin.y, bottom.x-origin.x, bottom.y-origin.y);
}

- (CGRect)convertRect:(CGRect)toConvert toView:(UIView *)toView
{
    CGPoint origin = [self convertPoint:CGPointMake(CGRectGetMinX(toConvert),CGRectGetMinY(toConvert)) toView:toView];
    CGPoint bottom = [self convertPoint:CGPointMake(CGRectGetMaxX(toConvert),CGRectGetMaxY(toConvert)) toView:toView];
    return CGRectMake(origin.x, origin.y, bottom.x-origin.x, bottom.y-origin.y);
}

- (void)sizeToFit
{
    CGRect frame = self.frame;
    frame.size = [self sizeThatFits:frame.size];
    self.frame = frame;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return size;
}

- (UIView *)viewWithTag:(NSInteger)tagToFind
{
    UIView *foundView = nil;
    
    if (self.tag == tagToFind) {
        foundView = self;
    } else {
        // 从后向前找.
        for (UIView *view in [self.subviews reverseObjectEnumerator]) {
            foundView = [view viewWithTag:tagToFind];
            if (foundView)
                break;
        }
    }
    
    return foundView;
}

// 循环判断.
- (BOOL)isDescendantOfView:(UIView *)view
{
    if (view) {
        UIView *testView = self;
        while (testView) {
            if (testView == view) {
                return YES;
            } else {
                testView = testView.superview;
            }
        }
    }
    return NO;
}

// 简简单单的通知 layer 需要进行更新了.
- (void)setNeedsDisplay
{
    [_layer setNeedsDisplay];
}

- (void)setNeedsDisplayInRect:(CGRect)invalidRect
{
    [_layer setNeedsDisplayInRect:invalidRect];
}

- (void)drawRect:(CGRect)rect
{
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    // For notes about why this is done, see displayLayer: above.
    if (aSelector == @selector(displayLayer:)) {
        return !_implementsDrawRect;
    } else {
        return [super respondsToSelector:aSelector];
    }
}

#pragma mark - CALayerDelegate

/*
 You can implement the methods of this protocol to provide the layer’s content, handle the layout of sublayers, and provide custom animation actions to perform.
 The object that implements this protocol must be assigned to the delegate property of the layer object.
 */

/*
 The displayLayer: delegate method is invoked when the layer is marked for its content to be reloaded, typically initiated by the setNeedsDisplay method.
 The typical technique for updating is to set the layer's contents property.
 在 displayLayer 里面, 一般做的事, 将 layer 的 contents 进行设置, 这样 layer 就会显示.
 然后, layer 的重绘过程就会结束, 其他的代理方法也就不会执行了.
 */

- (void)displayLayer:(CALayer *)theLayer
{
    // Okay, this is some crazy stuff right here. Basically, the real UIKit avoids creating any contents for its layer if there's no drawRect:
    // specified in the UIView's subview. This nicely prevents a ton of useless memory usage and likley improves performance a lot on iPhone.
    // It took great pains to discover this trick and I think I'm doing this right. By having this method empty here, it means that it overrides
    // the layer's normal display method and instead does nothing which results in the layer not making a backing store and wasting memory.
    
    // Here's how CALayer appears to work:
    // 1- something call's the layer's -display method.
    // 2- arrive in CALayer's display: method.
    // 2a-  if delegate implements displayLayer:, call that.
    // 2b-  if delegate doesn't implement displayLayer:, CALayer creates a buffer and a context and passes that to drawInContext:
    // 3- arrive in CALayer's drawInContext: method.
    // 3a-  if delegate implements drawLayer:inContext:, call that and pass it the context.
    // 3b-  otherwise, does nothing
    
    // So, what this all means is that to avoid causing the CALayer to create a context and use up memory, our delegate has to lie to CALayer
    // about if it implements displayLayer: or not. If we say it does, we short circuit the layer's buffer creation process (since it assumes
    // we are going to be setting it's contents property ourselves). So, that's what we do in the override of respondsToSelector: below.
    
    // backgroundColor is influenced by all this as well. If drawRect: is defined, we draw it directly in the context so that blending is all
    // pretty and stuff. If it isn't, though, we still want to support it. What the real UIKit does is it sets the layer's backgroundColor
    // iff drawRect: isn't specified. Otherwise it manages it itself. Again, this is for performance reasons. Rather than having to store a
    // whole bitmap the size of view just to hold the backgroundColor, this allows a lot of views to simply act as containers and not waste
    // a bunch of unnecessary memory in those cases - but you can still use background colors because CALayer manages that effeciently.
    
    // note that the last time I checked this, the layer's background color was being set immediately on call to -setBackgroundColor:
    // when there was no -drawRect: implementation, but I needed to change this to work around issues with pattern image colors in HiDPI.
    _layer.backgroundColor = [self.backgroundColor _bestRepresentationForProposedScale:self.window.screen.scale].CGColor;
}


// 核心方法. 如果  displayLayer 没有实现的化, 就会到达这里来. 在这里, 应该利用上下文进行绘制工作. 也就是说, layer 的内部管理者上下文的创建.
- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    // We only get here if the UIView subclass implements drawRect:. To do this without a drawRect: is a huge waste of memory.
    // See the discussion in drawLayer: above.

    const CGRect bounds = CGContextGetClipBoundingBox(ctx);

    UIGraphicsPushContext(ctx);
    CGContextSaveGState(ctx);
    if (_clearsContextBeforeDrawing) {
        CGContextClearRect(ctx, bounds);
    }
    if (_backgroundColor) {
        [_backgroundColor setFill];
        CGContextFillRect(ctx,bounds);
    }
    CGContextSetShouldSmoothFonts(ctx, NO);
    CGContextSetShouldSubpixelPositionFonts(ctx, YES);
    CGContextSetShouldSubpixelQuantizeFonts(ctx, YES);
    [[UIColor blackColor] set];
    [self drawRect:bounds]; // 在这里, 在进行了一些准备工作以后, 就会调用 drawRect 方法.
    CGContextRestoreGState(ctx);
    UIGraphicsPopContext();
}

- (void)_superviewSizeDidChangeFrom:(CGSize)oldSize to:(CGSize)newSize
{
    if (_autoresizingMask != UIViewAutoresizingNone) {
        CGRect frame = self.frame;
        const CGSize delta = CGSizeMake(newSize.width-oldSize.width, newSize.height-oldSize.height);
        
#define hasAutoresizingFor(x) ((_autoresizingMask & (x)) == (x))

        if (hasAutoresizingFor(UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin)) {
            frame.origin.y = floorf(frame.origin.y + (frame.origin.y / oldSize.height * delta.height));
            frame.size.height = floorf(frame.size.height + (frame.size.height / oldSize.height * delta.height));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight)) {
            const CGFloat t = frame.origin.y + frame.size.height;
            frame.origin.y = floorf(frame.origin.y + (frame.origin.y / t * delta.height));
            frame.size.height = floorf(frame.size.height + (frame.size.height / t * delta.height));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight)) {
            frame.size.height = floorf(frame.size.height + (frame.size.height / (oldSize.height - frame.origin.y) * delta.height));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin)) {
            frame.origin.y = floorf(frame.origin.y + (delta.height / 2.f));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleHeight)) {
            frame.size.height = floorf(frame.size.height + delta.height);
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleTopMargin)) {
            frame.origin.y = floorf(frame.origin.y + delta.height);
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleBottomMargin)) {
            frame.origin.y = floorf(frame.origin.y);
        }

        if (hasAutoresizingFor(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin)) {
            frame.origin.x = floorf(frame.origin.x + (frame.origin.x / oldSize.width * delta.width));
            frame.size.width = floorf(frame.size.width + (frame.size.width / oldSize.width * delta.width));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth)) {
            const CGFloat t = frame.origin.x + frame.size.width;
            frame.origin.x = floorf(frame.origin.x + (frame.origin.x / t * delta.width));
            frame.size.width = floorf(frame.size.width + (frame.size.width / t * delta.width));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth)) {
            frame.size.width = floorf(frame.size.width + (frame.size.width / (oldSize.width - frame.origin.x) * delta.width));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin)) {
            frame.origin.x = floorf(frame.origin.x + (delta.width / 2.f));
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleWidth)) {
            frame.size.width = floorf(frame.size.width + delta.width);
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleLeftMargin)) {
            frame.origin.x = floorf(frame.origin.x + delta.width);
        } else if (hasAutoresizingFor(UIViewAutoresizingFlexibleRightMargin)) {
            frame.origin.x = floorf(frame.origin.x);
        }
        self.frame = frame;
    }
}

- (void)_boundsDidChangeFrom:(CGRect)oldBounds to:(CGRect)newBounds
{
    if (!CGRectEqualToRect(oldBounds, newBounds)) {
        [self setNeedsLayout];
        if (!CGSizeEqualToSize(oldBounds.size, newBounds.size)) {
            if (_autoresizesSubviews) {
                for (UIView *subview in [_subviews allObjects]) {
                    [subview _superviewSizeDidChangeFrom:oldBounds.size to:newBounds.size];
                }
            }
        }
    }
}

+ (NSSet *)keyPathsForValuesAffectingFrame
{
    return [NSSet setWithObject:@"center"];
}

// 下面是关于 frame 的变化的一些设置的回调. 可以看到, 大部分其实还是在操作 layer.

- (CGRect)frame
{
    return _layer.frame;
}

- (void)setFrame:(CGRect)newFrame
{
    if (!CGRectEqualToRect(newFrame,_layer.frame)) {
        CGRect oldBounds = _layer.bounds;
        _layer.frame = newFrame;
        [self _boundsDidChangeFrom:oldBounds to:_layer.bounds];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIViewFrameDidChangeNotification object:self];
    }
}

- (CGRect)bounds
{
    return _layer.bounds;
}

- (void)setBounds:(CGRect)newBounds
{
    if (!CGRectEqualToRect(newBounds,_layer.bounds)) {
        CGRect oldBounds = _layer.bounds;
        _layer.bounds = newBounds;
        [self _boundsDidChangeFrom:oldBounds to:newBounds];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIViewBoundsDidChangeNotification object:self];
    }
}

- (CGPoint)center
{
    return _layer.position;
}

- (void)setCenter:(CGPoint)newCenter
{
    if (!CGPointEqualToPoint(newCenter,_layer.position)) {
        _layer.position = newCenter;
    }
}

- (CGAffineTransform)transform
{
    return _layer.affineTransform;
}

- (void)setTransform:(CGAffineTransform)transform
{
    if (!CGAffineTransformEqualToTransform(transform,_layer.affineTransform)) {
        _layer.affineTransform = transform;
    }
}

- (CGFloat)alpha
{
    return _layer.opacity;
}

- (void)setAlpha:(CGFloat)newAlpha
{
    if (newAlpha != _layer.opacity) {
        _layer.opacity = newAlpha;
    }
}

- (BOOL)isOpaque
{
    return _layer.opaque;
}

- (void)setOpaque:(BOOL)newO
{
    if (newO != _layer.opaque) {
        _layer.opaque = newO;
    }
}

- (void)setBackgroundColor:(UIColor *)newColor
{
    if (_backgroundColor != newColor) {
        _backgroundColor = newColor;
        self.opaque = [_backgroundColor _isOpaque];
        [self setNeedsDisplay];
    }
}

- (BOOL)clipsToBounds
{
    return _layer.masksToBounds;
}

- (void)setClipsToBounds:(BOOL)clips
{
    if (clips != _layer.masksToBounds) {
        _layer.masksToBounds = clips;
    }
}

- (void)setContentStretch:(CGRect)rect
{
    if (!CGRectEqualToRect(rect,_layer.contentsCenter)) {
        _layer.contentsCenter = rect;
    }
}

- (CGRect)contentStretch
{
    return _layer.contentsCenter;
}

- (void)setContentScaleFactor:(CGFloat)scale
{
    if (scale <= 0 && _implementsDrawRect) {
        scale = [UIScreen mainScreen].scale;
    }
    
    if (scale > 0 && scale != self.contentScaleFactor) {
        if ([_layer respondsToSelector:@selector(setContentsScale:)]) {
            [_layer setContentsScale:scale];
            [self setNeedsDisplay];
        }
    }
}

- (CGFloat)contentScaleFactor
{
    return [_layer respondsToSelector:@selector(contentsScale)]? [_layer contentsScale] : 1;
}

- (void)setHidden:(BOOL)h
{
    if (h != _layer.hidden) {
        _layer.hidden = h;
        [[NSNotificationCenter defaultCenter] postNotificationName:UIViewHiddenDidChangeNotification object:self];
    }
}

- (BOOL)isHidden
{
    return _layer.hidden;
}

/**
 You can call this method to indicate that the layout of a layer’s sublayers has changed and must be updated. The system typically calls this method automatically when the layer’s bounds change or when sublayers are added or removed. In macOS, if your layer’s layoutManager property contains an object that implements the invalidateLayoutOfLayer: method, that method is called too.

 During the next update cycle, the system calls the layoutSublayers method of any layers requiring layout updates.
 */

- (void)setNeedsLayout
{
    [_layer setNeedsLayout];
}

- (void)layoutIfNeeded
{
    [_layer layoutIfNeeded];
}

- (void)layoutSubviews
{
}

- (void)_layoutSubviews
{
    // 内部方法, 做了一些对于其他地方的通知操作, 然后调用 layoutSubviews
    const BOOL wereEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO]; // 在 UIView 的 layout 里面, 会关闭和打开 animation 的值, 这个值是全局的一个值, 表示是否动画.
    [self _UIAppearanceUpdateIfNeeded];
    [[self _viewController] viewWillLayoutSubviews]; // 通知 VC, 注入切口
    [self layoutSubviews]; // 自己的 layout 的切口
    [[self _viewController] viewDidLayoutSubviews]; // 通知 VC, 注入切口
    [UIView setAnimationsEnabled:wereEnabled]; // 打开动画控制.
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    return CGRectContainsPoint(self.bounds, point);
}

- (BOOL)_isAnimatedUserInteractionEnabled
{
    for (UIViewAnimationGroup *group in _animationGroupStack) {
        if (!group.allowUserInteraction) {
            for (UIView *animatingView in group.allAnimatingViews) {
                if ([self isDescendantOfView:animatingView]) {
                    return NO;
                }
            }
        }
    }
    
    return YES;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.hidden || !self.userInteractionEnabled || self.alpha < 0.01 || ![self pointInside:point withEvent:event] || ![self _isAnimatedUserInteractionEnabled]) {
        return nil;
    } else {
        for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
            UIView *hitView = [subview hitTest:[subview convertPoint:point fromView:self] withEvent:event];
            if (hitView) {
                return hitView;
            }
        }
        return self;
    }
}

// UIViewContentMode 的更改, 仅仅是改变 Layer 的contentsGravity属性的取值
- (void)setContentMode:(UIViewContentMode)mode
{
    if (mode != _contentMode) {
        _contentMode = mode;
        switch(_contentMode) {
            case UIViewContentModeScaleToFill:
                _layer.contentsGravity = kCAGravityResize;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeScaleAspectFit:
                _layer.contentsGravity = kCAGravityResizeAspect;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeScaleAspectFill:
                _layer.contentsGravity = kCAGravityResizeAspectFill;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeRedraw:
                // The option to redisplay the view when the bounds change by invoking the setNeedsDisplay method.
                _layer.needsDisplayOnBoundsChange = YES;
                break;
                
            case UIViewContentModeCenter:
                _layer.contentsGravity = kCAGravityCenter;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeTop:
                _layer.contentsGravity = kCAGravityTop;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeBottom:
                _layer.contentsGravity = kCAGravityBottom;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeLeft:
                _layer.contentsGravity = kCAGravityLeft;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeRight:
                _layer.contentsGravity = kCAGravityRight;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeTopLeft:
                _layer.contentsGravity = kCAGravityTopLeft;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeTopRight:
                _layer.contentsGravity = kCAGravityTopRight;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeBottomLeft:
                _layer.contentsGravity = kCAGravityBottomLeft;
                _layer.needsDisplayOnBoundsChange = NO;
                break;

            case UIViewContentModeBottomRight:
                _layer.contentsGravity = kCAGravityBottomRight;
                _layer.needsDisplayOnBoundsChange = NO;
                break;
        }
    }
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (![_gestureRecognizers containsObject:gestureRecognizer]) {
        [gestureRecognizer.view removeGestureRecognizer:gestureRecognizer];
        [_gestureRecognizers addObject:gestureRecognizer];
        [gestureRecognizer _setView:self];
    }
}

- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if ([_gestureRecognizers containsObject:gestureRecognizer]) {
        [gestureRecognizer _setView:nil];
        [_gestureRecognizers removeObject:gestureRecognizer];
    }
}

- (void)setGestureRecognizers:(NSArray *)newRecognizers
{
    for (UIGestureRecognizer *gesture in [_gestureRecognizers allObjects]) {
        [self removeGestureRecognizer:gesture];
    }

    for (UIGestureRecognizer *gesture in newRecognizers) {
        [self addGestureRecognizer:gesture];
    }	
}

- (NSArray *)gestureRecognizers
{
    return [_gestureRecognizers allObjects];
}

#pragma mark - AnimaitonRelated

// 在这里, 还是通过 [_animationGroupStack lastObject] 进行取值, 也就是说, 在 commits 的调用里面会到这里来, 因为在 groupCommit 之后就是 _animationGroupStack 的 removeLastObject 的操作了.
- (id)actionForLayer:(CALayer *)theLayer forKey:(NSString *)event
{
    if (_animationsEnabled && // 全局控制标明, 可以做动画
        [_animationGroupStack lastObject] && theLayer == _layer) {
        return [[_animationGroupStack lastObject] actionForView:self forKey:event] ?: (id)[NSNull null];
    } else {
        return [NSNull null];
    }
}

// 入栈操作, 然后下面的所有的设置, 都是取得这个栈的最后一个值, 然后进行设置.
// 之所以要全部通过栈的 lastObject 进行操作, 是因为在入栈出栈的过程中, 还非常有可能有着入栈的操作.
+ (void)_beginAnimationsWithOptions:(UIViewAnimationOptions)options
{
    [_animationGroupStack addObject:[[UIViewAnimationGroup alloc] initWithAnimationOptions:options]];
}

// 出栈操作, 将 animationGroup 中的信息, 创建一个动画, 提交给相应的 layer
+ (void)commitAnimations
{
    if ([_animationGroupStack count] > 0) {
        [[_animationGroupStack lastObject] commit];
        [_animationGroupStack removeLastObject];
    }
}

+ (void)_setAnimationName:(NSString *)name context:(void *)context
{
    [[_animationGroupStack lastObject] setName:name];
    [[_animationGroupStack lastObject] setContext:context];
}

+ (void)_setAnimationCompletionBlock:(void (^)(BOOL finished))completion
{
    [(UIViewAnimationGroup *)[_animationGroupStack lastObject] setCompletionBlock:completion];
}

+ (void (^)(BOOL))_animationCompletionBlock
{
    return [(UIViewAnimationGroup *)[_animationGroupStack lastObject] completionBlock];
}

+ (void)_setAnimationTransitionView:(UIView *)view
{
    [[_animationGroupStack lastObject] setTransitionView:view shouldCache:NO];
}

+ (BOOL)_isAnimating
{
    return ([_animationGroupStack count] != 0);
}

+ (void)setAnimationBeginsFromCurrentState:(BOOL)beginFromCurrentState
{
    [[_animationGroupStack lastObject] setBeginsFromCurrentState:beginFromCurrentState];
}

+ (void)setAnimationCurve:(UIViewAnimationCurve)curve
{
    [[_animationGroupStack lastObject] setCurve:curve];
}

+ (void)setAnimationDelay:(NSTimeInterval)delay
{
    [[_animationGroupStack lastObject] setDelay:delay];
}

+ (void)setAnimationDelegate:(id)delegate
{
    [[_animationGroupStack lastObject] setDelegate:delegate];
}

+ (void)setAnimationDidStopSelector:(SEL)selector
{
    [[_animationGroupStack lastObject] setDidStopSelector:selector];
}

+ (void)setAnimationDuration:(NSTimeInterval)duration
{
    [[_animationGroupStack lastObject] setDuration:duration];
}

+ (void)setAnimationRepeatAutoreverses:(BOOL)repeatAutoreverses
{
    [[_animationGroupStack lastObject] setRepeatAutoreverses:repeatAutoreverses];
}

+ (void)setAnimationRepeatCount:(float)repeatCount
{
    [[_animationGroupStack lastObject] setRepeatCount:repeatCount];
}

+ (void)setAnimationWillStartSelector:(SEL)selector
{
    [[_animationGroupStack lastObject] setWillStartSelector:selector];
}

+ (void)setAnimationTransition:(UIViewAnimationTransition)transition forView:(UIView *)view cache:(BOOL)cache
{
    [self _setAnimationTransitionView:view];
    
    switch (transition) {
        case UIViewAnimationTransitionNone:
            [[_animationGroupStack lastObject] setTransition:UIViewAnimationGroupTransitionNone];
            break;
            
        case UIViewAnimationTransitionFlipFromLeft:
            [[_animationGroupStack lastObject] setTransition:UIViewAnimationGroupTransitionFlipFromLeft];
            break;
            
        case UIViewAnimationTransitionFlipFromRight:
            [[_animationGroupStack lastObject] setTransition:UIViewAnimationGroupTransitionFlipFromRight];
            break;
            
        case UIViewAnimationTransitionCurlUp:
            [[_animationGroupStack lastObject] setTransition:UIViewAnimationGroupTransitionCurlUp];
            break;
            
        case UIViewAnimationTransitionCurlDown:
            [[_animationGroupStack lastObject] setTransition:UIViewAnimationGroupTransitionCurlDown];
            break;
    }
}

// 类方法, 会创建出一个数据对象来, 进行参数的收集工作, 然后这个数据对象, 会运用 CAAnimation 创建各种动画提交给动画系统. 所以, 类方法本质上还是没有脱离原始的动画系统.
// 这里复杂的是, animation block 里面还可能提交新的动画, 所以, 这是一个栈的结构.

+ (void)animateWithDuration:(NSTimeInterval)duration
                      delay:(NSTimeInterval)delay
                    options:(UIViewAnimationOptions)options
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion
{
    [self _beginAnimationsWithOptions:options | UIViewAnimationOptionTransitionNone];
    [self setAnimationDuration:duration];
    [self setAnimationDelay:delay];
    [self _setAnimationCompletionBlock:completion];
    animations(); // 如果在 animaiton 里面, 还有animateWithDuration:delay... 的调用, 会进行入栈, 只有出栈后, 这个动画才会提交.
    [self commitAnimations];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self animateWithDuration:duration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:animations
                   completion:completion];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    [self animateWithDuration:duration animations:animations completion:NULL];
}

+ (void)transitionWithView:(UIView *)view
                  duration:(NSTimeInterval)duration
                   options:(UIViewAnimationOptions)options
                animations:(void (^)(void))animations
                completion:(void (^)(BOOL finished))completion
{
    [self _beginAnimationsWithOptions:options];
    [self setAnimationDuration:duration];
    [self _setAnimationCompletionBlock:completion];
    [self _setAnimationTransitionView:view];
    if (animations) {
        animations(); // 在这里, 实际的修改了各个属性的值.
    }
    [self commitAnimations];
}

+ (void)transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options completion:(void (^)(BOOL finished))completion
{
    [self transitionWithView:fromView.superview
                    duration:duration
                     options:options
                  animations:^{
                      if (UIViewAnimationOptionIsSet(options, UIViewAnimationOptionShowHideTransitionViews)) {
                          fromView.hidden = YES;
                          toView.hidden = NO;
                      } else {
                          [fromView.superview addSubview:toView];
                          [fromView removeFromSuperview];
                      }
                  }
                  completion:completion];
}

+ (void)beginAnimations:(NSString *)animationID context:(void *)context
{
    [self _beginAnimationsWithOptions:UIViewAnimationCurveEaseInOut];
    [self _setAnimationName:animationID context:context];
}

+ (BOOL)areAnimationsEnabled
{
    return _animationsEnabled;
}

+ (void)setAnimationsEnabled:(BOOL)enabled
{
    _animationsEnabled = enabled;
}

@end
