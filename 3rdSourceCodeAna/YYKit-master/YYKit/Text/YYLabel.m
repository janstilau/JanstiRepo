#import "YYLabel.h"
#import "YYAsyncLayer.h"
#import "YYWeakProxy.h"
#import "YYCGUtilities.h"
#import "NSAttributedString+YYText.h"

#if __has_include("YYDispatchQueuePool.h")
#import "YYDispatchQueuePool.h"
#endif

#ifdef YYDispatchQueuePool_h
static dispatch_queue_t YYLabelGetReleaseQueue() {
    return YYDispatchQueueGetForQOS(NSQualityOfServiceUtility);
}
#else
static dispatch_queue_t YYLabelGetReleaseQueue() {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
}
#endif


static const CGFloat kLongPressMinimumDuration = 0.5;
static const CGFloat kLongPressAllowableMovement = 9.0;
static const CGFloat kHighlightFadeDuration = 0.15;
static const CGFloat kAsyncFadeDuration = 0.08;
 

@interface YYLabel() <YYTextDebugTarget, YYAsyncLayerDelegate> {
// 所有的数据项.

    NSMutableAttributedString *_innerText; ///< 文字的实体, 核心的数据
    YYTextLayout *_innerLayout; // 根据文字, 所产生的 lauout 类. 里面有着 CTFrame 的信息, 以及 attachMent 的记录信息.
    YYTextContainer *_innerContainer; /// 绘制相关的数据类, 在 layout 的生成过程, 会用到 container 和 attributeString
    
    // 只所以有这两个东西, 是因为 image 是画上去的, 相当于每次的重绘都是在新的画布上进行绘制. 而这两个是加到新的画布的上方的, 不属于绘画
    NSMutableArray *_viewAttachMents; // 表示, 正在显示的
    NSMutableArray *_layerAttachMents; // 表示, 正在显示的.
    
    NSRange _highlightRange; ///< current highlight range  在点击事件中, 会不断地更新这个区域.
    YYTextHighlight *_highlight; ///< highlight attribute in `_highlightRange` 在点击事件中, 会不断地更新这个数据.
    
/**
 *
 *  highLightLauout 是 innerLayout 的一次复制操作, 然后根据 YYHighLight 里面的属性, 对于高亮区域的属性进行改变. 所以高亮的绘制和普通的绘制基本是一样的, 仅仅是高亮部分的位置会有改变.
 * YYLayout 以及其他所有的数据, 都实现了 copy 的协议, 主要也是为了支持这里.
 */
    YYTextLayout *_highlightLayout; ///< when _state.showingHighlight=YES, this layout should be displayed
    
    YYTextLayout *_shrinkInnerLayout;
    YYTextLayout *_shrinkHighlightLayout;
    
    NSTimer *_longPressTimer; // 在 longPress 触发之后, 立马会进行 timer 的 invalidate, 所以长按操作只会触发一次.
    CGPoint _touchBeganPoint;
    
    struct {
        unsigned int layoutNeedUpdate : 1;
        unsigned int showingHighlight : 1;
        
        unsigned int trackingTouch : 1; // 正在触摸
        unsigned int swallowTouch : 1; // 是否将事件向上抛出, 这里是模拟 gesture 的实现. 在有高亮的处理的时候, 这个值为 YES, 组织点击, 移动事件向上传递.
        unsigned int touchMoved : 1; // 触摸移动了
        
        unsigned int hasTapAction : 1; // 是否有触摸事件, 根据_textTapAction
        unsigned int hasLongPressAction : 1; // 是否有长按事件, 根据 _textLongPressTapAction 属性
         
        unsigned int contentsNeedFade : 1; // 动画控制..
    } _currentState;
}
@end


@implementation YYLabel

#pragma mark - init

// 这里, 返回值决定了 View 相关的显示 layer 的类型.
+ (Class)layerClass {
    return [YYAsyncLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO; // 这个是绘图系统优化性能用的值.
    [self _initLabel];
    self.frame = frame;
    return self;
}

// init 方法.
- (void)_initLabel {
    ((YYAsyncLayer *)self.layer).displaysAsynchronously = NO; // 如果是异步, 则是在子线程绘制出 iamge 来, 然后来到主线程设置 contents.
    self.layer.contentsScale = [UIScreen mainScreen].scale;
    self.contentMode = UIViewContentModeRedraw;
    
    _viewAttachMents = [NSMutableArray new]; // 不是绘制, 而是 addSubview 的显示元素.
    _layerAttachMents = [NSMutableArray new]; // 不是绘制, 而是 addSubLayer 的显示元素.
    
    _debugOption = [YYTextDebugOption sharedDebugOption];
    [YYTextDebugOption addDebugTarget:self];
    
    _font = [self _defaultFont];
    _textColor = [UIColor blackColor];
    _textVerticalAlignment = YYTextVerticalAlignmentCenter;
    _numberOfLines = 1; // 模拟 UILabel
    _textAlignment = NSTextAlignmentNatural;
    _lineBreakMode = NSLineBreakByTruncatingTail;
    _innerText = [NSMutableAttributedString new]; // 真正的数据类.
    _innerContainer = [YYTextContainer new]; // Layout 的生成所需要的数据类. 里面是位置相关的一些信息. 说实话, 这里面的属性有点责任不明晰.
    _innerContainer.truncationType = YYTextTruncationTypeEnd;
    _innerContainer.maximumNumberOfRows = _numberOfLines;
    _clearContentsBeforeAsynchronouslyDisplay = YES;
    _fadeOnAsynchronouslyDisplay = YES;
    _fadeOnHighlight = YES;
}

- (void)dealloc {
    [YYTextDebugOption removeDebugTarget:self];
    [_longPressTimer invalidate];
}

- (void)setFrame:(CGRect)frame {
    CGSize oldSize = self.bounds.size;
    // 这里, 是实际的 YYLabel 的尺寸的改变
    [super setFrame:frame];
    
    CGSize newSize = self.bounds.size;
    // 如果, 尺寸发生了改变, 那么就需要触发重绘.
    if (!CGSizeEqualToSize(oldSize, newSize)) {
        _innerContainer.size = self.bounds.size;
        if (!_ignoreCommonProperties) {
            _currentState.layoutNeedUpdate = YES;
        }
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) { // 这样做的意义是什么.
            [self _clearContents];
        }
        [self.layer setNeedsDisplay];
    }
}

- (void)setBounds:(CGRect)bounds {
    CGSize oldSize = self.bounds.size;
    [super setBounds:bounds];
    // 实际修改 YYLabel 的尺寸.
    
    CGSize newSize = self.bounds.size;
    if (!CGSizeEqualToSize(oldSize, newSize)) {
        _innerContainer.size = self.bounds.size;
        if (!_ignoreCommonProperties) {
            _currentState.layoutNeedUpdate = YES;
        }
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self.layer setNeedsDisplay];
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (_ignoreCommonProperties) {  // 如果
        return _innerLayout.textBoundingSize;
    }
    
    if (!_verticalForm && size.width <= 0) size.width = YYTextContainerMaxSize.width;
    if (_verticalForm && size.height <= 0) size.height = YYTextContainerMaxSize.height;
    
    if ((!_verticalForm && size.width == self.bounds.size.width) ||
        (_verticalForm && size.height == self.bounds.size.height)) {
        [self _updateIfNeeded];
        YYTextLayout *layout = self._innerLayout;
        BOOL contains = NO;
        if (layout.container.maximumNumberOfRows == 0) {
            if (layout.truncatedLine == nil) {
                contains = YES;
            }
        } else {
            if (layout.rowCount <= layout.container.maximumNumberOfRows) {
                contains = YES;
            }
        }
        if (contains) {
            return layout.textBoundingSize;
        }
    }
    
    if (!_verticalForm) {
        size.height = YYTextContainerMaxSize.height;
    } else {
        size.width = YYTextContainerMaxSize.width;
    }
    
    YYTextContainer *container = [_innerContainer copy];
    container.size = size;
    YYTextLayout *layout = [YYTextLayout layoutWithContainer:container text:_innerText];
    return layout.textBoundingSize; // 一边无限制, 计算在另外一边有限制的情况下, size 的大小.
}

#pragma mark - Private

- (void)_setLayoutNeedUpdate { // 只是设置为需要 updateLayout
    _currentState.layoutNeedUpdate = YES; // 将自己的状态设置为 dirty. 并且清空自己的 layout.
    [self _clearInnerLayout];
    [self.layer setNeedsDisplay];
}

- (void)_updateIfNeeded { // 真正的 upateLayout
    if (_currentState.layoutNeedUpdate) { // 如果自己的 layout 状态是 dirty 状态, 那么就更新自己的 layout, 然后重绘.
        _currentState.layoutNeedUpdate = NO;
        _innerLayout = [YYTextLayout layoutWithContainer:_innerContainer text:_innerText];
        _shrinkInnerLayout = [YYLabel _shrinkLayoutWithLayout:_innerLayout];
        [self.layer setNeedsDisplay];
    }
}

- (void)_clearInnerLayout {
    if (!_innerLayout) return;
    YYTextLayout *layout = _innerLayout;
    _innerLayout = nil;
    _shrinkInnerLayout = nil;
    dispatch_async(YYLabelGetReleaseQueue(), ^{
        NSAttributedString *text = [layout text]; // capture to block and release in background
        if (layout.attachments.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [text length]; // capture to block and release in main thread (maybe there's UIView/CALayer attachments).
            });
        }
    });
}

- (YYTextLayout *)_innerLayout {
    return _shrinkInnerLayout ? _shrinkInnerLayout : _innerLayout;
}

- (YYTextLayout *)_highlightLayout {
    return _shrinkHighlightLayout ? _shrinkHighlightLayout : _highlightLayout;
}

// 返回一行的 layout.
+ (YYTextLayout *)_shrinkLayoutWithLayout:(YYTextLayout *)layout {
    if (layout.text.length && layout.lines.count == 0) {
        YYTextContainer *container = layout.container.copy;
        container.maximumNumberOfRows = 1;
        CGSize containerSize = container.size;
        if (!container.verticalForm) {
            containerSize.height = YYTextContainerMaxSize.height;
        } else {
            containerSize.width = YYTextContainerMaxSize.width;
        }
        container.size = containerSize;
        return [YYTextLayout layoutWithContainer:container text:layout.text];
    } else {
        return nil;
    }
}

#pragma mark - Interaction

// 在 touchBegin 的时候, 就开启一个定时器, 如果定时器可以到达特定的时间, 就代表可以进行触发长按收拾. 如果中途触发了取消手势的操作, 这个定时器会移除.
- (void)_startLongPressTimer {
    [_longPressTimer invalidate];
    _longPressTimer = [NSTimer timerWithTimeInterval:kLongPressMinimumDuration
                                              target:[YYWeakProxy proxyWithTarget:self]
                                            selector:@selector(_trackDidLongPress)
                                            userInfo:nil
                                             repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:_longPressTimer forMode:NSRunLoopCommonModes];
}

- (void)_endLongPressTimer {
    [_longPressTimer invalidate];
    _longPressTimer = nil;
}

// 这其实就是 longPressGesture 的处理过程.
- (void)_trackDidLongPress {
    [self _endLongPressTimer]; // 触发了
    if (_currentState.hasLongPressAction && _textLongPressAction) { // 如果有长按事件回调. hasLongPressAction 这个值其实可以直接用 _textLongPressAction 判断出来啊, 猜测是, 为了和 hasTapAction 统一, 因为 hasTapAction 其实是可以根据, Label 的 tapAction 和 AttributeString 里面的 highLightAction 两个属性共同控制的.
        NSRange range = NSMakeRange(NSNotFound, 0);
        CGRect rect = CGRectNull;
        CGPoint point = [self _convertPointToLayout:_touchBeganPoint]; // 长按, 代表着点击后手指没移动, touchBegin 就是点击位置
        YYTextRange *textRange = [self._innerLayout textRangeAtPoint:point];
        CGRect textRect = [self._innerLayout rectForRange:textRange];
        textRect = [self _convertRectFromLayout:textRect];
        if (textRange) {
            range = textRange.asRange;
            rect = textRect;
        }
        // 所有的位置相关的信息, 都在 layout 中, Layout 里面有着 CTFrame, CTLine, CTRun 所以可以获取到所有的这些信息.
        _textLongPressAction(self, _innerText, range, rect);
    }
    
    // 如果有高亮的长按回调, 也要调用者一部分的回调.
    if (_highlight) {
        YYTextAction longPressAction = _highlight.longPressAction ? _highlight.longPressAction : _highlightLongPressAction;
        if (longPressAction) {
            // YYTextPosition 就是以 offset 为数据的数据类, YYKit 增加了方向的概念.
            YYTextPosition *start = [YYTextPosition positionWithOffset:_highlightRange.location];
            YYTextPosition *end = [YYTextPosition positionWithOffset:_highlightRange.location + _highlightRange.length affinity:YYTextAffinityBackward];
            YYTextRange *range = [YYTextRange rangeWithStart:start end:end];
            CGRect rect = [self._innerLayout rectForRange:range];
            rect = [self _convertRectFromLayout:rect];
            longPressAction(self, _innerText, _highlightRange, rect);
            [self _removeHighlightAnimated:YES];
            _currentState.trackingTouch = NO;
        }
    }
}

- (YYTextHighlight *)_getHighlightAtPoint:(CGPoint)point range:(NSRangePointer)range {
    if (!self._innerLayout.containsHighlight) return nil;
    point = [self _convertPointToLayout:point];
    YYTextRange *textRange = [self._innerLayout textRangeAtPoint:point];
    // 获取 point 点附近, 可以算作统一 attributes 的 text 的 range.
    if (!textRange) return nil;
    
    NSUInteger startIndex = textRange.start.offset;
    if (startIndex == _innerText.length) {
        if (startIndex > 0) {
            startIndex--;
        }
    }
    // 获取点击位置位置文字的高亮属性.
    NSRange highlightRange = {0};
    YYTextHighlight *highlight = [_innerText attribute:YYTextHighlightAttributeName
                                               atIndex:startIndex
                                 longestEffectiveRange:&highlightRange
                                               inRange:NSMakeRange(0, _innerText.length)];\
    
    if (!highlight) return nil;
    if (range) *range = highlightRange;
    return highlight;
}

// _highlightLayout 仅仅是 innerTextLayout 的一个拷贝, 并且改变了高亮位置的文字的状态.
- (void)_showHighlightAnimated:(BOOL)animated {
    if (!_highlight) return;
    if (!_highlightLayout) {
        NSMutableAttributedString *hiText = _innerText.mutableCopy;
        NSDictionary *newAttrs = _highlight.attributes;
        [newAttrs enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            [hiText setAttribute:key value:value range:_highlightRange];
        }];
        _highlightLayout = [YYTextLayout layoutWithContainer:_innerContainer text:hiText];
        _shrinkHighlightLayout = [YYLabel _shrinkLayoutWithLayout:_highlightLayout];
        if (!_highlightLayout) _highlight = nil;
    }
    
    if (_highlightLayout && !_currentState.showingHighlight) {
        _currentState.showingHighlight = YES;
        _currentState.contentsNeedFade = animated;
        [self.layer setNeedsDisplay];
    }
}

- (void)_hideHighlightAnimated:(BOOL)animated {
    if (_currentState.showingHighlight) {
        _currentState.showingHighlight = NO;
        _currentState.contentsNeedFade = animated;
        [self.layer setNeedsDisplay];
    }
}

- (void)_removeHighlightAnimated:(BOOL)animated {
    [self _hideHighlightAnimated:animated];
    _highlight = nil;
    _highlightLayout = nil;
    _shrinkHighlightLayout = nil;
}

- (void)_endTouch {
    [self _endLongPressTimer];
    [self _removeHighlightAnimated:YES];
    _currentState.trackingTouch = NO;
}

//
- (CGPoint)_convertPointToLayout:(CGPoint)point {
    CGSize boundingSize = self._innerLayout.textBoundingSize;
    if (self._innerLayout.container.isVerticalForm) {
        CGFloat w = self._innerLayout.textBoundingSize.width;
        if (w < self.bounds.size.width) w = self.bounds.size.width;
        point.x += self._innerLayout.container.size.width - w;
        if (_textVerticalAlignment == YYTextVerticalAlignmentCenter) {
            point.x += (self.bounds.size.width - boundingSize.width) * 0.5;
        } else if (_textVerticalAlignment == YYTextVerticalAlignmentBottom) {
            point.x += (self.bounds.size.width - boundingSize.width);
        }
        return point;
    } else {
        if (_textVerticalAlignment == YYTextVerticalAlignmentCenter) {
            point.y -= (self.bounds.size.height - boundingSize.height) * 0.5;
        } else if (_textVerticalAlignment == YYTextVerticalAlignmentBottom) {
            point.y -= (self.bounds.size.height - boundingSize.height);
        }
        return point;
    }
}

- (CGPoint)_convertPointFromLayout:(CGPoint)point {
    CGSize boundingSize = self._innerLayout.textBoundingSize;
    if (self._innerLayout.container.isVerticalForm) {
        CGFloat w = self._innerLayout.textBoundingSize.width;
        if (w < self.bounds.size.width) w = self.bounds.size.width;
        point.x -= self._innerLayout.container.size.width - w;
        if (boundingSize.width < self.bounds.size.width) {
            if (_textVerticalAlignment == YYTextVerticalAlignmentCenter) {
                point.x -= (self.bounds.size.width - boundingSize.width) * 0.5;
            } else if (_textVerticalAlignment == YYTextVerticalAlignmentBottom) {
                point.x -= (self.bounds.size.width - boundingSize.width);
            }
        }
        return point;
    } else {
        if (boundingSize.height < self.bounds.size.height) {
            if (_textVerticalAlignment == YYTextVerticalAlignmentCenter) {
                point.y += (self.bounds.size.height - boundingSize.height) * 0.5;
            } else if (_textVerticalAlignment == YYTextVerticalAlignmentBottom) {
                point.y += (self.bounds.size.height - boundingSize.height);
            }
        }
        return point;
    }
}

- (CGRect)_convertRectToLayout:(CGRect)rect {
    rect.origin = [self _convertPointToLayout:rect.origin];
    return rect;
}

- (CGRect)_convertRectFromLayout:(CGRect)rect {
    rect.origin = [self _convertPointFromLayout:rect.origin];
    return rect;
}

- (UIFont *)_defaultFont {
    return [UIFont systemFontOfSize:17];
}

- (NSShadow *)_shadowFromProperties {
    if (!_shadowColor || _shadowBlurRadius < 0) return nil;
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = _shadowColor;
#if !TARGET_INTERFACE_BUILDER
    shadow.shadowOffset = _shadowOffset;
#else
    shadow.shadowOffset = CGSizeMake(_shadowOffset.x, _shadowOffset.y);
#endif
    shadow.shadowBlurRadius = _shadowBlurRadius;
    return shadow;
}

// 所谓的 updateOuter, 就是将这些属性, 暴露到外界去. 因为所有的属性, 其实都在 layout 中, 所以, 专门有这样的一个方法, 将里面的值抽取出来. 这里, 都用计算属性, 其实代码会太复杂, 所以用了空间存储了这些值, 减少了代码的长度.

- (void)_updateOuterLineBreakMode {
    if (_innerContainer.truncationType) {
        switch (_innerContainer.truncationType) {
            case YYTextTruncationTypeStart: {
                _lineBreakMode = NSLineBreakByTruncatingHead;
            } break;
            case YYTextTruncationTypeEnd: {
                _lineBreakMode = NSLineBreakByTruncatingTail;
            } break;
            case YYTextTruncationTypeMiddle: {
                _lineBreakMode = NSLineBreakByTruncatingMiddle;
            } break;
            default:break;
        }
    } else {
        _lineBreakMode = _innerText.lineBreakMode;
    }
}

- (void)_updateOuterTextProperties {
    _text = [_innerText plainTextForRange:NSMakeRange(0, _innerText.length)];
    _font = _innerText.font;
    if (!_font) _font = [self _defaultFont];
    _textColor = _innerText.color;
    if (!_textColor) _textColor = [UIColor blackColor];
    _textAlignment = _innerText.alignment;
    _lineBreakMode = _innerText.lineBreakMode;
    NSShadow *shadow = _innerText.shadow;
    _shadowColor = shadow.shadowColor;
    _shadowOffset = shadow.shadowOffset;
    
    _shadowBlurRadius = shadow.shadowBlurRadius;
    _attributedText = _innerText;
    [self _updateOuterLineBreakMode];
}

- (void)_updateOuterContainerProperties {
    _truncationToken = _innerContainer.truncationToken;
    _numberOfLines = _innerContainer.maximumNumberOfRows;
    _textContainerPath = _innerContainer.path;
    _exclusionPaths = _innerContainer.exclusionPaths;
    _textContainerInset = _innerContainer.insets;
    _verticalForm = _innerContainer.verticalForm;
    _linePositionModifier = _innerContainer.linePositionModifier;
    [self _updateOuterLineBreakMode];
}


// 更新自己当前的显示到空白.
- (void)_clearContents {
    CGImageRef image = (__bridge_retained CGImageRef)(self.layer.contents);
    self.layer.contents = nil;
    if (image) {
        dispatch_async(YYLabelGetReleaseQueue(), ^{
            CFRelease(image);
        });
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:_attributedText forKey:@"attributedText"];
    [aCoder encodeObject:_innerContainer forKey:@"innerContainer"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self _initLabel];
    YYTextContainer *innerContainer = [aDecoder decodeObjectForKey:@"innerContainer"];
    if (innerContainer) {
        _innerContainer = innerContainer;
    } else {
        _innerContainer.size = self.bounds.size;
    }
    [self _updateOuterContainerProperties];
    self.attributedText = [aDecoder decodeObjectForKey:@"attributedText"];
    [self _setLayoutNeedUpdate];
    return self;
}

#pragma mark - Touches

// YYLabel 对于 touch 的处理, 可以猜测苹果的各个手势的实现过程.

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self _updateIfNeeded];
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];
    
    _highlight = [self _getHighlightAtPoint:point range:&_highlightRange];
    _highlightLayout = nil;
    _shrinkHighlightLayout = nil;
    _currentState.hasTapAction = _textTapAction != nil;
    _currentState.hasLongPressAction = _textLongPressAction != nil;
    
    if (_highlight || // 当前触摸位置的动作
        _textTapAction || // 整个 YYLabel 的触摸动作
        _textLongPressAction) { // 整个 YYLabel 的长按动作.
        _touchBeganPoint = point;
        _currentState.trackingTouch = YES;
        _currentState.swallowTouch = YES; // 如果这个设置为 YES, 其他 touch 就不会处理, 可以算作, 所有的touch 操作都是被这个类进行处理. 从这可以猜想, 为什么 button 可以拦截自己的触摸事件.
        _currentState.touchMoved = NO;
        [self _startLongPressTimer];
        if (_highlight) [self _showHighlightAnimated:NO]; // 更新 highLight 位置的高亮.
    } else {
        _currentState.trackingTouch = NO;
        _currentState.swallowTouch = NO;
        _currentState.touchMoved = NO;
    }
    if (!_currentState.swallowTouch) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self _updateIfNeeded];
    
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];
    
    if (_currentState.trackingTouch) {
        if (!_currentState.touchMoved) {
            CGFloat moveH = point.x - _touchBeganPoint.x;
            CGFloat moveV = point.y - _touchBeganPoint.y;
            if (fabs(moveH) > fabs(moveV)) {
                if (fabs(moveH) > kLongPressAllowableMovement) _currentState.touchMoved = YES;
            } else {
                if (fabs(moveV) > kLongPressAllowableMovement) _currentState.touchMoved = YES;
            }
            // 根据偏移量, 来判断, 其实这里可以变为 swipeGesture 的实现.
            /*
             cancelsTouchesInView
             delaysTouchesBegan
             delaysTouchesEnded
             上面三个属性的实现逻辑, 应该和这里的实现是类似的.
             */
            if (_currentState.touchMoved) { // 如果移动了, 就放弃 longPressTimer
                [self _endLongPressTimer];
            }
        }
        
        // 下面就是替换高亮的区域了.
        if (_currentState.touchMoved && _highlight) {
            YYTextHighlight *highlight = [self _getHighlightAtPoint:point range:NULL];
            if (highlight == _highlight) {
                [self _showHighlightAnimated:_fadeOnHighlight];
            } else {
                [self _hideHighlightAnimated:_fadeOnHighlight];
            }
        }
    }
    
    if (!_currentState.swallowTouch) {
        [super touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];
    
    if (_currentState.trackingTouch) {
        [self _endLongPressTimer];
        // 如果没有移动, 那么就可以调用点击事件的回调了, tapGesture 的处理过程.
        // 这里可以看做是 tapGesture 的实现. 在点击并且end 的时候, 触发 tap 动作的回调.
        if (!_currentState.touchMoved && _textTapAction) {
            NSRange range = NSMakeRange(NSNotFound, 0);
            CGRect rect = CGRectNull;
            CGPoint point = [self _convertPointToLayout:_touchBeganPoint];
            YYTextRange *textRange = [self._innerLayout textRangeAtPoint:point];
            CGRect textRect = [self._innerLayout rectForRange:textRange];
            textRect = [self _convertRectFromLayout:textRect];
            if (textRange) {
                range = textRange.asRange;
                rect = textRect;
            }
            _textTapAction(self, _innerText, range, rect);
        }
        // 如果点击位置有高亮的回调,
        if (_highlight) { // 并且没有移动, 或者移动的范围, 没有出高亮回调的范围, 那么这个回调还是可以使用.
            if (!_currentState.touchMoved || [self _getHighlightAtPoint:point range:NULL] == _highlight) {
                YYTextAction tapAction = _highlight.tapAction ? _highlight.tapAction : _highlightTapAction;
                if (tapAction) {
                    YYTextPosition *start = [YYTextPosition positionWithOffset:_highlightRange.location];
                    YYTextPosition *end = [YYTextPosition positionWithOffset:_highlightRange.location + _highlightRange.length affinity:YYTextAffinityBackward];
                    YYTextRange *range = [YYTextRange rangeWithStart:start end:end];
                    CGRect rect = [self._innerLayout rectForRange:range];
                    rect = [self _convertRectFromLayout:rect];
                    tapAction(self, _innerText, _highlightRange, rect);
                }
            }
            [self _removeHighlightAnimated:_fadeOnHighlight];
        }
    }
    
    if (!_currentState.swallowTouch) {
        [super touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self _endTouch];
    if (!_currentState.swallowTouch) [super touchesCancelled:touches withEvent:event];
}

#pragma mark - Properties

// text 的改变, 会引起下面所有的属性的重新计算, 然后设置当前的状态失效并且触发重绘的操作.
- (void)setText:(NSString *)text {
    if (_text == text || [_text isEqualToString:text]) return;
    _text = text.copy;
    BOOL needAddAttributes = _innerText.length == 0 && text.length > 0;
    [_innerText replaceCharactersInRange:NSMakeRange(0, _innerText.length) withString:text ? text : @""];
    [_innerText removeDiscontinuousAttributesInRange:NSMakeRange(0, _innerText.length)];
    // YYLabel 完全是用 NSAttributeString 来控制自己的显示, 其实可能 Label 也是这样的. 因为 attributeString 的功能完全可以替换 plainString
    if (needAddAttributes) {
        _innerText.font = _font;
        _innerText.color = _textColor;
        _innerText.shadow = [self _shadowFromProperties];
        _innerText.alignment = _textAlignment;
        switch (_lineBreakMode) {
            case NSLineBreakByWordWrapping:
            case NSLineBreakByCharWrapping:
            case NSLineBreakByClipping: {
                _innerText.lineBreakMode = _lineBreakMode;
            } break;
            case NSLineBreakByTruncatingHead:
            case NSLineBreakByTruncatingTail:
            case NSLineBreakByTruncatingMiddle: {
                _innerText.lineBreakMode = NSLineBreakByWordWrapping;
            } break;
            default: break;
        }
    }
    if ([_textParser parseText:_innerText selectedRange:NULL]) {
        [self _updateOuterTextProperties];
    }
    if (!_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setFont:(UIFont *)font {
    if (!font) {
        font = [self _defaultFont];
    }
    if (_font == font || [_font isEqual:font]) return;
    _font = font;
    _innerText.font = _font;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize]; // 影响 autolayout.
    }
}

- (void)setTextColor:(UIColor *)textColor {
    if (!textColor) {
        textColor = [UIColor blackColor];
    }
    if (_textColor == textColor || [_textColor isEqual:textColor]) return;
    _textColor = textColor;
    _innerText.color = textColor;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
    }
}

- (void)setShadowColor:(UIColor *)shadowColor {
    if (_shadowColor == shadowColor || [_shadowColor isEqual:shadowColor]) return;
    _shadowColor = shadowColor;
    _innerText.shadow = [self _shadowFromProperties];
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
    }
}

#if !TARGET_INTERFACE_BUILDER
- (void)setShadowOffset:(CGSize)shadowOffset {
    if (CGSizeEqualToSize(_shadowOffset, shadowOffset)) return;
    _shadowOffset = shadowOffset;
    _innerText.shadow = [self _shadowFromProperties];
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
    }
}
#else
- (void)setShadowOffset:(CGPoint)shadowOffset {
    if (CGPointEqualToPoint(_shadowOffset, shadowOffset)) return;
    _shadowOffset = shadowOffset;
    _innerText.shadow = [self _shadowFromProperties];
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
    }
}
#endif

- (void)setShadowBlurRadius:(CGFloat)shadowBlurRadius {
    if (_shadowBlurRadius == shadowBlurRadius) return;
    _shadowBlurRadius = shadowBlurRadius;
    _innerText.shadow = [self _shadowFromProperties];
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
    }
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    if (_textAlignment == textAlignment) return;
    _textAlignment = textAlignment;
    _innerText.alignment = textAlignment;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    if (_lineBreakMode == lineBreakMode) return;
    _lineBreakMode = lineBreakMode;
    _innerText.lineBreakMode = lineBreakMode;
    // allow multi-line break
    switch (lineBreakMode) {
        case NSLineBreakByWordWrapping:
        case NSLineBreakByCharWrapping:
        case NSLineBreakByClipping: {
            _innerContainer.truncationType = YYTextTruncationTypeNone;
            _innerText.lineBreakMode = lineBreakMode;
        } break;
        case NSLineBreakByTruncatingHead:{
            _innerContainer.truncationType = YYTextTruncationTypeStart;
            _innerText.lineBreakMode = NSLineBreakByWordWrapping;
        } break;
        case NSLineBreakByTruncatingTail:{
            _innerContainer.truncationType = YYTextTruncationTypeEnd;
            _innerText.lineBreakMode = NSLineBreakByWordWrapping;
        } break;
        case NSLineBreakByTruncatingMiddle: {
            _innerContainer.truncationType = YYTextTruncationTypeMiddle;
            _innerText.lineBreakMode = NSLineBreakByWordWrapping;
        } break;
        default: break;
    }
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setTextVerticalAlignment:(YYTextVerticalAlignment)textVerticalAlignment {
    if (_textVerticalAlignment == textVerticalAlignment) return;
    _textVerticalAlignment = textVerticalAlignment;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setTruncationToken:(NSAttributedString *)truncationToken {
    if (_truncationToken == truncationToken || [_truncationToken isEqual:truncationToken]) return;
    _truncationToken = truncationToken.copy;
    _innerContainer.truncationToken = truncationToken;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setNumberOfLines:(NSUInteger)numberOfLines {
    if (_numberOfLines == numberOfLines) return;
    _numberOfLines = numberOfLines;
    _innerContainer.maximumNumberOfRows = numberOfLines;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (attributedText.length > 0) {
        _innerText = attributedText.mutableCopy;
        switch (_lineBreakMode) {
            case NSLineBreakByWordWrapping:
            case NSLineBreakByCharWrapping:
            case NSLineBreakByClipping: {
                _innerText.lineBreakMode = _lineBreakMode;
            } break;
            case NSLineBreakByTruncatingHead:
            case NSLineBreakByTruncatingTail:
            case NSLineBreakByTruncatingMiddle: {
                _innerText.lineBreakMode = NSLineBreakByWordWrapping;
            } break;
            default: break;
        }
    } else {
        _innerText = [NSMutableAttributedString new];
    }
    [_textParser parseText:_innerText selectedRange:NULL];
    if (!_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _updateOuterTextProperties];
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setTextContainerPath:(UIBezierPath *)textContainerPath {
    if (_textContainerPath == textContainerPath || [_textContainerPath isEqual:textContainerPath]) return;
    _textContainerPath = textContainerPath.copy;
    _innerContainer.path = textContainerPath;
    if (!_textContainerPath) {
        _innerContainer.size = self.bounds.size;
        _innerContainer.insets = _textContainerInset;
    }
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setExclusionPaths:(NSArray *)exclusionPaths {
    if (_exclusionPaths == exclusionPaths || [_exclusionPaths isEqual:exclusionPaths]) return;
    _exclusionPaths = exclusionPaths.copy;
    _innerContainer.exclusionPaths = exclusionPaths;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    if (UIEdgeInsetsEqualToEdgeInsets(_textContainerInset, textContainerInset)) return;
    _textContainerInset = textContainerInset;
    _innerContainer.insets = textContainerInset;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setVerticalForm:(BOOL)verticalForm {
    if (_verticalForm == verticalForm) return;
    _verticalForm = verticalForm;
    _innerContainer.verticalForm = verticalForm;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setLinePositionModifier:(id<YYTextLinePositionModifier>)linePositionModifier {
    if (_linePositionModifier == linePositionModifier) return;
    _linePositionModifier = linePositionModifier;
    _innerContainer.linePositionModifier = linePositionModifier;
    if (_innerText.length && !_ignoreCommonProperties) {
        if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
            [self _clearContents];
        }
        [self _setLayoutNeedUpdate];
        [self _endTouch];
        [self invalidateIntrinsicContentSize];
    }
}

- (void)setTextParser:(id<YYTextParser>)textParser {
    if (_textParser == textParser || [_textParser isEqual:textParser]) return;
    _textParser = textParser;
    if ([_textParser parseText:_innerText selectedRange:NULL]) {
        [self _updateOuterTextProperties];
        if (!_ignoreCommonProperties) {
            if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
                [self _clearContents];
            }
            [self _setLayoutNeedUpdate];
            [self _endTouch];
            [self invalidateIntrinsicContentSize];
        }
    }
}

- (void)setTextLayout:(YYTextLayout *)textLayout {
    _innerLayout = textLayout;
    _shrinkInnerLayout = nil;
    
    if (_ignoreCommonProperties) {
        _innerText = (NSMutableAttributedString *)textLayout.text;
        _innerContainer = textLayout.container.copy;
    } else {
        _innerText = textLayout.text.mutableCopy;
        if (!_innerText) {
            _innerText = [NSMutableAttributedString new];
        }
        [self _updateOuterTextProperties];
        
        _innerContainer = textLayout.container.copy;
        if (!_innerContainer) {
            _innerContainer = [YYTextContainer new];
            _innerContainer.size = self.bounds.size;
            _innerContainer.insets = self.textContainerInset;
        }
        [self _updateOuterContainerProperties];
    }
    
    if (_displaysAsynchronously && _clearContentsBeforeAsynchronouslyDisplay) {
        [self _clearContents];
    }
    _currentState.layoutNeedUpdate = NO;
    [self.layer setNeedsDisplay];
    [self _endTouch];
    [self invalidateIntrinsicContentSize];
}

- (YYTextLayout *)textLayout {
    [self _updateIfNeeded];
    return _innerLayout;
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously {
    _displaysAsynchronously = displaysAsynchronously;
    ((YYAsyncLayer *)self.layer).displaysAsynchronously = displaysAsynchronously;
}

// 可以看到, 上面的属性的重新设置, 都会影响到 layout 的内部属性的变化, 而这种变化, 会引起视图的变化, 所以都调用重绘函数, setNeedDisplay. 所以, 这些所有的操作, 都会进行引起 draw 方法的调用. 而由于 runloop 的存在, 这些重绘只会出现一次.

#pragma mark - AutoLayout

- (void)setPreferredMaxLayoutWidth:(CGFloat)preferredMaxLayoutWidth {
    if (_preferredMaxLayoutWidth == preferredMaxLayoutWidth) return;
    _preferredMaxLayoutWidth = preferredMaxLayoutWidth;
    [self invalidateIntrinsicContentSize];
}

- (CGSize)intrinsicContentSize {
    if (_preferredMaxLayoutWidth == 0) {
        YYTextContainer *container = [_innerContainer copy];
        container.size = YYTextContainerMaxSize;
        
        YYTextLayout *layout = [YYTextLayout layoutWithContainer:container text:_innerText];
        return layout.textBoundingSize; // 可以看到, 其实 YYKit 的作者, 也是用 layout 的这个值, 当做 YYLabel 的 size 的大小的. 从这里看来, textBoundingSize 里面应该是考虑到了 inset 的值了.
    }
    
    CGSize containerSize = _innerContainer.size;
    if (!_verticalForm) {
        containerSize.height = YYTextContainerMaxSize.height;
        containerSize.width = _preferredMaxLayoutWidth;
        if (containerSize.width == 0) containerSize.width = self.bounds.size.width;
    } else {
        containerSize.width = YYTextContainerMaxSize.width;
        containerSize.height = _preferredMaxLayoutWidth;
        if (containerSize.height == 0) containerSize.height = self.bounds.size.height;
    }
    
    YYTextContainer *container = [_innerContainer copy];
    container.size = containerSize;
    
    YYTextLayout *layout = [YYTextLayout layoutWithContainer:container text:_innerText];
    return layout.textBoundingSize;
}

#pragma mark - YYTextDebugTarget

- (void)setDebugOption:(YYTextDebugOption *)debugOption {
    BOOL needDraw = _debugOption.needDrawDebug;
    _debugOption = debugOption.copy;
    if (_debugOption.needDrawDebug != needDraw) {
        [self.layer setNeedsDisplay];
    }
}

#pragma mark - YYAsyncLayerDelegate


// 最重要的一步, 如何绘制就在这个函数里面.
- (YYAsyncLayerDisplayTask *)newAsyncDisplayTask {
    
    // capture current context
    // 这里, 利用 block, 保存了 context 的值.
    BOOL contentsNeedFade = _currentState.contentsNeedFade;
    NSAttributedString *text = _innerText;
    YYTextContainer *container = _innerContainer;
    YYTextVerticalAlignment verticalAlignment = _textVerticalAlignment;
    YYTextDebugOption *debug = _debugOption;
    NSMutableArray *attachmentViews = _viewAttachMents;
    NSMutableArray *attachmentLayers = _layerAttachMents;
    BOOL layoutNeedUpdate = _currentState.layoutNeedUpdate;
    BOOL fadeForAsync = _displaysAsynchronously && _fadeOnAsynchronouslyDisplay;
    __block YYTextLayout *currentLayout = (_currentState.showingHighlight && _highlightLayout) ? self._highlightLayout : self._innerLayout; // 如果有高亮的, 就是在高亮点击的状态.
    __block YYTextLayout *shrinkLayout = nil;
    __block BOOL layoutUpdated = NO;
    if (layoutNeedUpdate) {
        text = text.copy;
        container = container.copy;
    }
    
    // create display task
    YYAsyncLayerDisplayTask *task = [[YYAsyncLayerDisplayTask alloc] init];
    // willDisplay 做的事情, 都是 draw 的过程无法控制的过程. 最主要的原因是,attachmentViews,attachmentLayers 是通过 addSubView 和 addSubLayer 的形式, 进行的视图的控制.
    task.willDisplay = ^(CALayer *layer) {
        [layer removeAnimationForKey:@"contents"]; // 首先, 把动画移出了. 之所以要移除, 是因为在 didDisplay 中添加了动画.
        
        // If the attachment is not in new layout, or we don't know the new layout currently,
        // the attachment should be removed.
        // 当布局改变只是, 所有 attach 重新添加, 当现有 attach 没有该 attach 时, 所有 attach 移出.
        for (UIView *view in attachmentViews) {
            if (layoutNeedUpdate || ![currentLayout.attachmentContentsSet containsObject:view]) {
                if (view.superview == self) {
                    [view removeFromSuperview];
                }
            }
        }
        for (CALayer *layer in attachmentLayers) {
            if (layoutNeedUpdate || ![currentLayout.attachmentContentsSet containsObject:layer]) {
                if (layer.superlayer == self.layer) {
                    [layer removeFromSuperlayer];
                }
            }
        }
        [attachmentViews removeAllObjects];
        [attachmentLayers removeAllObjects];
    };
    
    // 真正的绘画过程, YYLabel 到底显示什么样子, 就看这里面对于 context 上画什么东西.
    task.display = ^(CGContextRef context, CGSize size, BOOL (^isCancelled)(void)) {
        if (isCancelled()) return; // 如果, 取消了, 直接返回. 注意, isCancelled 是一个闭包, 所以这是一个动态值.
        if (text.length == 0) return; //如果没有文字, 直接返回.
        
        YYTextLayout *drawLayout = currentLayout;
        if (layoutNeedUpdate) {
            currentLayout = [YYTextLayout layoutWithContainer:container text:text];
            shrinkLayout = [YYLabel _shrinkLayoutWithLayout:currentLayout];
            if (isCancelled()) return;
            layoutUpdated = YES;
            drawLayout = shrinkLayout ? shrinkLayout : currentLayout;
        }
        
        CGSize boundingSize = drawLayout.textBoundingSize;
        CGPoint point = CGPointZero;
        // 这里, 根据垂直方向的布局, 修改起始点的坐标.
        if (verticalAlignment == YYTextVerticalAlignmentCenter) {
            if (drawLayout.container.isVerticalForm) { // 是不是竖排.
                point.x = -(size.width - boundingSize.width) * 0.5;
            } else {
                point.y = (size.height - boundingSize.height) * 0.5;
            }
        } else if (verticalAlignment == YYTextVerticalAlignmentBottom) {
            if (drawLayout.container.isVerticalForm) { // 是不是竖排.
                point.x = -(size.width - boundingSize.width);
            } else {
                point.y = (size.height - boundingSize.height);
            }
        }
        point = CGPointPixelRound(point);
        // 参数都是一些位置的信息, 而真正该画什么内容, 其实还是保存在 drawLayout 当中
        [drawLayout drawInContext:context size:size point:point view:nil layer:nil debug:debug cancel:isCancelled];
    };
    
    task.didDisplay = ^(CALayer *layer, BOOL finished) {
        YYTextLayout *drawLayout = currentLayout;
        if (layoutUpdated && shrinkLayout) {
            drawLayout = shrinkLayout;
        }
        if (!finished) {
            // If the display task is cancelled, we should clear the attachments.
            for (YYTextAttachment *a in drawLayout.attachments) {
                if ([a.content isKindOfClass:[UIView class]]) {
                    if (((UIView *)a.content).superview == layer.delegate) {
                        [((UIView *)a.content) removeFromSuperview];
                    }
                } else if ([a.content isKindOfClass:[CALayer class]]) {
                    if (((CALayer *)a.content).superlayer == layer) {
                        [((CALayer *)a.content) removeFromSuperlayer];
                    }
                }
            }
            return;
        }
        [layer removeAnimationForKey:@"contents"];
        
        __strong YYLabel *view = (YYLabel *)layer.delegate;
        if (!view) return;
        if (view->_currentState.layoutNeedUpdate && layoutUpdated) {
            view->_innerLayout = currentLayout;
            view->_shrinkInnerLayout = shrinkLayout;
            view->_currentState.layoutNeedUpdate = NO;
        }
        
        CGSize size = layer.bounds.size;
        CGSize boundingSize = drawLayout.textBoundingSize;
        CGPoint point = CGPointZero;
        if (verticalAlignment == YYTextVerticalAlignmentCenter) {
            if (drawLayout.container.isVerticalForm) {
                point.x = -(size.width - boundingSize.width) * 0.5;
            } else {
                point.y = (size.height - boundingSize.height) * 0.5;
            }
        } else if (verticalAlignment == YYTextVerticalAlignmentBottom) {
            if (drawLayout.container.isVerticalForm) {
                point.x = -(size.width - boundingSize.width);
            } else {
                point.y = (size.height - boundingSize.height);
            }
        }
        point = CGPointPixelRound(point);
        [drawLayout drawInContext:nil size:size point:point view:view layer:layer debug:nil cancel:NULL];
        for (YYTextAttachment *a in drawLayout.attachments) {
            // 在这里, 更新 attachView 相关的一些信息.
            if ([a.content isKindOfClass:[UIView class]]) [attachmentViews addObject:a.content];
            else if ([a.content isKindOfClass:[CALayer class]]) [attachmentLayers addObject:a.content];
        }
        
        // 如果, 需要动画, 那么就增加一个动画到 layer 上面.
        if (contentsNeedFade) {
            CATransition *transition = [CATransition animation];
            transition.duration = kHighlightFadeDuration;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            transition.type = kCATransitionFade;
            [layer addAnimation:transition forKey:@"contents"];
        } else if (fadeForAsync) {
            CATransition *transition = [CATransition animation];
            transition.duration = kAsyncFadeDuration;
            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            transition.type = kCATransitionFade;
            [layer addAnimation:transition forKey:@"contents"];
        }
    };
    
    return task;
}

@end



@interface YYLabel(IBInspectableProperties)
@end

@implementation YYLabel (IBInspectableProperties)

- (BOOL)fontIsBold_:(UIFont *)font {
    if (![font respondsToSelector:@selector(fontDescriptor)]) return NO;
    return (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) > 0;
}

- (UIFont *)boldFont_:(UIFont *)font {
    if (![font respondsToSelector:@selector(fontDescriptor)]) return font;
    return [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
}

- (UIFont *)normalFont_:(UIFont *)font {
    if (![font respondsToSelector:@selector(fontDescriptor)]) return font;
    return [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:0] size:font.pointSize];
}

- (void)setFontName_:(NSString *)fontName {
    if (!fontName) return;
    UIFont *font = self.font;
    if ((fontName.length == 0 || [fontName.lowercaseString isEqualToString:@"system"]) && ![self fontIsBold_:font]) {
        font = [UIFont systemFontOfSize:font.pointSize];
    } else if ([fontName.lowercaseString isEqualToString:@"system bold"]) {
        font = [UIFont boldSystemFontOfSize:font.pointSize];
    } else {
        if ([self fontIsBold_:font] && ![fontName.lowercaseString containsString:@"bold"]) {
            font = [UIFont fontWithName:fontName size:font.pointSize];
            font = [self boldFont_:font];
        } else {
            font = [UIFont fontWithName:fontName size:font.pointSize];
        }
    }
    if (font) self.font = font;
}

- (void)setFontSize_:(CGFloat)fontSize {
    if (fontSize <= 0) return;
    UIFont *font = self.font;
    font = [font fontWithSize:fontSize];
    if (font) self.font = font;
}

- (void)setFontIsBold_:(BOOL)fontBold {
    UIFont *font = self.font;
    if ([self fontIsBold_:font] == fontBold) return;
    if (fontBold) {
        font = [self boldFont_:font];
    } else {
        font = [self normalFont_:font];
    }
    if (font) self.font = font;
}

- (void)setInsetTop_:(CGFloat)textInsetTop {
    UIEdgeInsets insets = self.textContainerInset;
    insets.top = textInsetTop;
    self.textContainerInset = insets;
}

- (void)setInsetBottom_:(CGFloat)textInsetBottom {
    UIEdgeInsets insets = self.textContainerInset;
    insets.bottom = textInsetBottom;
    self.textContainerInset = insets;
}

- (void)setInsetLeft_:(CGFloat)textInsetLeft {
    UIEdgeInsets insets = self.textContainerInset;
    insets.left = textInsetLeft;
    self.textContainerInset = insets;
    
}

- (void)setInsetRight_:(CGFloat)textInsetRight {
    UIEdgeInsets insets = self.textContainerInset;
    insets.right = textInsetRight;
    self.textContainerInset = insets;
}

- (void)setDebugEnabled_:(BOOL)enabled {
    if (!enabled) {
        self.debugOption = nil;
    } else {
        YYTextDebugOption *debugOption = [YYTextDebugOption new];
        debugOption.baselineColor = [UIColor redColor];
        debugOption.CTFrameBorderColor = [UIColor redColor];
        debugOption.CTLineFillColor = [UIColor colorWithRed:0.000 green:0.463 blue:1.000 alpha:0.180];
        debugOption.CGGlyphBorderColor = [UIColor colorWithRed:1.000 green:0.524 blue:0.000 alpha:0.200];
        self.debugOption = debugOption;
    }
}

@end
