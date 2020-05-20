#import "ZFPlayerGestureControl.h"

@interface ZFPlayerGestureControl ()<UIGestureRecognizerDelegate>

// 各个交互的手势信息.
@property (nonatomic, strong) UITapGestureRecognizer *singleTap;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTap;
@property (nonatomic, strong) UIPanGestureRecognizer *panGR;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGR;

// 滑动的手势方向信息.
@property (nonatomic) ZFPanDirection panDirection;
@property (nonatomic) ZFPanLocation panLocation;
@property (nonatomic) ZFPanMovingDirection panMovingDirection;

@property (nonatomic, weak) UIView *targetView;

@end

@implementation ZFPlayerGestureControl

// 在这个方法里面, 添加了各种各样的手势, 并且通过懒加载进行了初始化的工作.
- (void)addGestureToView:(UIView *)view {
    self.targetView = view;
    self.targetView.multipleTouchEnabled = YES;
    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];
    [self.singleTap  requireGestureRecognizerToFail:self.panGR];
    [self.targetView addGestureRecognizer:self.singleTap];
    [self.targetView addGestureRecognizer:self.doubleTap];
    [self.targetView addGestureRecognizer:self.panGR];
    [self.targetView addGestureRecognizer:self.pinchGR];
}

// 进行手势的移除的操作, 这会在 playManager 替换的时候进行.
- (void)removeGestureToView:(UIView *)view {
    [view removeGestureRecognizer:self.singleTap];
    [view removeGestureRecognizer:self.doubleTap];
    [view removeGestureRecognizer:self.panGR];
    [view removeGestureRecognizer:self.pinchGR];
}

// 手势的代理工作. 在这里, 通过 disablePanMovingDirection 的设置, 可以屏蔽某些手势.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGR) {
        CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.targetView];
        CGFloat x = fabs(translation.x);
        CGFloat y = fabs(translation.y);
        if (x < y && self.disablePanMovingDirection & ZFPlayerDisablePanMovingDirectionVertical) { /// up and down moving direction.
            return NO;
        } else if (x > y && self.disablePanMovingDirection & ZFPlayerDisablePanMovingDirectionHorizontal) { /// left and right moving direction.
            return NO;
        }
    }
    return YES;
}

// 手势的代理. 在这里, 通过各个 disable 的设置, 可以进行某些操作的屏蔽.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    ZFPlayerGestureType type = ZFPlayerGestureTypeUnknown;
    if (gestureRecognizer == self.singleTap) type = ZFPlayerGestureTypeSingleTap;
    else if (gestureRecognizer == self.doubleTap) type = ZFPlayerGestureTypeDoubleTap;
    else if (gestureRecognizer == self.panGR) type = ZFPlayerGestureTypePan;
    else if (gestureRecognizer == self.pinchGR) type = ZFPlayerGestureTypePinch;
    CGPoint locationPoint = [touch locationInView:touch.view];
    if (locationPoint.x > _targetView.bounds.size.width / 2) {
        self.panLocation = ZFPanLocationRight;
    } else {
        self.panLocation = ZFPanLocationLeft;
    }
    
    switch (type) {
        case ZFPlayerGestureTypeUnknown: break;
        case ZFPlayerGestureTypePan: {
            if (self.disableTypes & ZFPlayerDisableGestureTypesPan) {
                return NO;
            }
        }
            break;
        case ZFPlayerGestureTypePinch: {
            if (self.disableTypes & ZFPlayerDisableGestureTypesPinch) {
                return NO;
            }
        }
            break;
        case ZFPlayerGestureTypeDoubleTap: {
            if (self.disableTypes & ZFPlayerDisableGestureTypesDoubleTap) {
                return NO;
            }
        }
            break;
        case ZFPlayerGestureTypeSingleTap: {
            if (self.disableTypes & ZFPlayerDisableGestureTypesSingleTap) {
                return NO;
            }
        }
            break;
    }
    
    if (self.triggerCondition) return self.triggerCondition(self, type, gestureRecognizer, touch);
    return YES;
}

// Whether to support multi-trigger, return YES, you can trigger a method with multiple gestures, return NO is mutually exclusive
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (otherGestureRecognizer != self.singleTap &&
        otherGestureRecognizer != self.doubleTap &&
        otherGestureRecognizer != self.panGR &&
        otherGestureRecognizer != self.pinchGR) return NO;
    
    if (gestureRecognizer == self.panGR) {
        CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.targetView];
        CGFloat x = fabs(translation.x);
        CGFloat y = fabs(translation.y);
        if (x < y && self.disablePanMovingDirection & ZFPlayerDisablePanMovingDirectionVertical) {
            return YES;
        } else if (x > y && self.disablePanMovingDirection & ZFPlayerDisablePanMovingDirectionHorizontal) {
            return YES;
        }
    }
    if (gestureRecognizer.numberOfTouches >= 2) {
        return NO;
    }
    return YES;
}

- (UITapGestureRecognizer *)singleTap {
    if (!_singleTap){
        _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
        _singleTap.delegate = self;
        _singleTap.delaysTouchesBegan = YES;
        _singleTap.delaysTouchesEnded = YES;
        _singleTap.numberOfTouchesRequired = 1;  
        _singleTap.numberOfTapsRequired = 1;
    }
    return _singleTap;
}

- (UITapGestureRecognizer *)doubleTap {
    if (!_doubleTap) {
        _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTap.delegate = self;
        _doubleTap.delaysTouchesBegan = YES;
        _singleTap.delaysTouchesEnded = YES;
        _doubleTap.numberOfTouchesRequired = 1; 
        _doubleTap.numberOfTapsRequired = 2;
    }
    return _doubleTap;
}

- (UIPanGestureRecognizer *)panGR {
    if (!_panGR) {
        _panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGR.delegate = self;
        _panGR.delaysTouchesBegan = YES;
        _panGR.delaysTouchesEnded = YES;
        _panGR.maximumNumberOfTouches = 1;
        _panGR.cancelsTouchesInView = YES;
    }
    return _panGR;
}

- (UIPinchGestureRecognizer *)pinchGR {
    if (!_pinchGR) {
        _pinchGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        _pinchGR.delegate = self;
        _pinchGR.delaysTouchesBegan = YES;
    }
    return _pinchGR;
}

#pragma mark - ActionHandle

// 就是简单的触发回调调用, 对于 Pan, 进行了大量的取值操作.

- (void)handleSingleTap:(UITapGestureRecognizer *)tap {
    if (self.singleTapped) self.singleTapped(self);
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if (self.doubleTapped) self.doubleTapped(self);
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translate = [pan translationInView:pan.view];
    CGPoint velocity = [pan velocityInView:pan.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            self.panMovingDirection = ZFPanMovingDirectionUnkown;
            CGFloat x = fabs(velocity.x);
            CGFloat y = fabs(velocity.y);
            if (x > y) {
                self.panDirection = ZFPanDirectionH;
            } else if (x < y) {
                self.panDirection = ZFPanDirectionV;
            } else {
                self.panDirection = ZFPanDirectionUnknown;
            }
            
            if (self.beganPan) self.beganPan(self, self.panDirection, self.panLocation);
        }
            break;
        case UIGestureRecognizerStateChanged: {
            switch (_panDirection) {
                case ZFPanDirectionH: {
                    if (translate.x > 0) {
                        self.panMovingDirection = ZFPanMovingDirectionRight;
                    } else if (translate.y < 0) {
                        self.panMovingDirection = ZFPanMovingDirectionLeft;
                    }
                }
                    break;
                case ZFPanDirectionV: {
                    if (translate.y > 0) {
                        self.panMovingDirection = ZFPanMovingDirectionBottom;
                    } else {
                        self.panMovingDirection = ZFPanMovingDirectionTop;
                    }
                }
                    break;
                case ZFPanDirectionUnknown:
                    break;
            }
            if (self.changedPan) self.changedPan(self, self.panDirection, self.panLocation, velocity);
        }
            break;
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            if (self.endedPan) self.endedPan(self, self.panDirection, self.panLocation);
        }
            break;
        default:
            break;
    }
    [pan setTranslation:CGPointZero inView:pan.view];
}

- (void)handlePinch:(UIPinchGestureRecognizer *)pinch {
    switch (pinch.state) {
        case UIGestureRecognizerStateEnded: {
            if (self.pinched) self.pinched(self, pinch.scale);
        }
            break;
        default:
            break;
    }
}

@end
