#import "UIView.h"

// Control 的 Event, 是各个 Control 通过追踪事件判断出来的.
typedef NS_OPTIONS(NSUInteger, UIControlEvents) {
    UIControlEventTouchDown           = 1 <<  0,
    UIControlEventTouchDownRepeat     = 1 <<  1,
    UIControlEventTouchDragInside     = 1 <<  2,
    UIControlEventTouchDragOutside    = 1 <<  3,
    UIControlEventTouchDragEnter      = 1 <<  4,
    UIControlEventTouchDragExit       = 1 <<  5,
    UIControlEventTouchUpInside       = 1 <<  6,
    UIControlEventTouchUpOutside      = 1 <<  7,
    UIControlEventTouchCancel         = 1 <<  8,
    
    UIControlEventValueChanged        = 1 << 12,
    
    UIControlEventEditingDidBegin     = 1 << 16,
    UIControlEventEditingChanged      = 1 << 17,
    UIControlEventEditingDidEnd       = 1 << 18,
    UIControlEventEditingDidEndOnExit = 1 << 19,
    
    UIControlEventAllTouchEvents      = 0x00000FFF,
    UIControlEventAllEditingEvents    = 0x000F0000,
    UIControlEventApplicationReserved = 0x0F000000,
    UIControlEventSystemReserved      = 0xF0000000,
    UIControlEventAllEvents           = 0xFFFFFFFF
};

// 根据 touch 的过程, state 的状态不断的更新. 他们之前是或的关系, 也就是说, 可以同时有着多种状态.
typedef NS_OPTIONS(NSUInteger, UIControlState) {
    UIControlStateNormal               = 0,
    UIControlStateHighlighted          = 1 << 0,
    UIControlStateDisabled             = 1 << 1,
    UIControlStateSelected             = 1 << 2,
    UIControlStateApplication          = 0x00FF0000,
    UIControlStateReserved             = 0xFF000000
};

// 这就是一个状态值, 至于这个状态值到底有什么意义, 是需要各个子类自定义的.
typedef NS_ENUM(NSInteger, UIControlContentHorizontalAlignment) {
    UIControlContentHorizontalAlignmentCenter = 0,
    UIControlContentHorizontalAlignmentLeft    = 1,
    UIControlContentHorizontalAlignmentRight = 2,
    UIControlContentHorizontalAlignmentFill   = 3,
};

// 这就是一个状态值, 至于这个状态值到底有什么意义, 是需要各个子类自定义的.
typedef NS_ENUM(NSInteger, UIControlContentVerticalAlignment) {
    UIControlContentVerticalAlignmentCenter  = 0,
    UIControlContentVerticalAlignmentTop     = 1,
    UIControlContentVerticalAlignmentBottom  = 2,
    UIControlContentVerticalAlignmentFill    = 3,
};

@class UITouch;

@interface UIControl : UIView
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)controlEvent;
- (NSSet *)allTargets;
- (UIControlEvents)allControlEvents;

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event;

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event;
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event;
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event;
- (void)cancelTrackingWithEvent:(UIEvent *)event;

@property (nonatomic, readonly) UIControlState state;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;

@property (nonatomic, readonly, getter=isTracking) BOOL tracking;
@property (nonatomic, readonly, getter=isTouchInside) BOOL touchInside;

@property (nonatomic) UIControlContentHorizontalAlignment contentHorizontalAlignment;
@property (nonatomic) UIControlContentVerticalAlignment contentVerticalAlignment;
@end
