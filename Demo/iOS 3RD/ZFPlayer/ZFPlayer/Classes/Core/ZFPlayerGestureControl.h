#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ZFPlayerGestureType) {
    ZFPlayerGestureTypeUnknown,
    ZFPlayerGestureTypeSingleTap, // 单点效果, 一般用于控制层的显示和隐藏
    ZFPlayerGestureTypeDoubleTap, // 双点效果, 一般用于视频的播放和暂停
    ZFPlayerGestureTypePan, // 移动效果, 一般左边用户
    ZFPlayerGestureTypePinch // 捏合效果, 在这个类库中, 用于进行了填充效果的变化工作.
};

// 这两个枚举值, 是根据 translate 的 x, y 的绝对值的比较获得的. 这要比之前记录一个值, 然后判断当前值和新值之间的间距要好用.
typedef NS_ENUM(NSUInteger, ZFPanDirection) {
    ZFPanDirectionUnknown,
    ZFPanDirectionV, // 竖直滑动
    ZFPanDirectionH, // 左右滑动
};

// 是在左半部分滑动的, 还是在右半部分滑动的. 这个是根据 gesture 在 View 的位置来进行的判断.
typedef NS_ENUM(NSUInteger, ZFPanLocation) {
    ZFPanLocationUnknown,
    ZFPanLocationLeft,
    ZFPanLocationRight,
};

// 下面的这四个值, 是在 ZFPanDirection 确定之后, 根据 x, y 值的正负判断出来的.
typedef NS_ENUM(NSUInteger, ZFPanMovingDirection) {
    ZFPanMovingDirectionUnkown,
    ZFPanMovingDirectionTop,
    ZFPanMovingDirectionLeft,
    ZFPanMovingDirectionBottom,
    ZFPanMovingDirectionRight,
};

// 这个是用来判断. 当前要不要进行某个手势的判断.
typedef NS_OPTIONS(NSUInteger, ZFPlayerDisableGestureTypes) {
    ZFPlayerDisableGestureTypesNone         = 0,
    ZFPlayerDisableGestureTypesSingleTap    = 1 << 0,
    ZFPlayerDisableGestureTypesDoubleTap    = 1 << 1,
    ZFPlayerDisableGestureTypesPan          = 1 << 2,
    ZFPlayerDisableGestureTypesPinch        = 1 << 3,
    ZFPlayerDisableGestureTypesAll          = (ZFPlayerDisableGestureTypesSingleTap | ZFPlayerDisableGestureTypesDoubleTap | ZFPlayerDisableGestureTypesPan | ZFPlayerDisableGestureTypesPinch)
};

// 这个是用来判断, pan 这种手势, 哪一种不想要处理.
typedef NS_OPTIONS(NSUInteger, ZFPlayerDisablePanMovingDirection) {
    ZFPlayerDisablePanMovingDirectionNone         = 0,       /// Not disable pan moving direction.
    ZFPlayerDisablePanMovingDirectionVertical     = 1 << 0,  /// Disable pan moving vertical direction.
    ZFPlayerDisablePanMovingDirectionHorizontal   = 1 << 1,  /// Disable pan moving horizontal direction.
    ZFPlayerDisablePanMovingDirectionAll          = (ZFPlayerDisablePanMovingDirectionVertical | ZFPlayerDisablePanMovingDirectionHorizontal)  /// Disable pan moving all direction.
};


// 视频的操作有一个很常规的模式, 所以, 这个类就是这个操作模式的实现. 通过添加不同的手势, 来实现触摸的逻辑, 而这些触摸之后真正要实现什么样的逻辑, 通过回调的方式暴露出去.

@interface ZFPlayerGestureControl : NSObject

/// Gesture condition callback.
@property (nonatomic, copy, nullable) BOOL(^triggerCondition)(ZFPlayerGestureControl *control, ZFPlayerGestureType type, UIGestureRecognizer *gesture, UITouch *touch);

/// Single tap gesture callback.
@property (nonatomic, copy, nullable) void(^singleTapped)(ZFPlayerGestureControl *control);

/// Double tap gesture callback.
@property (nonatomic, copy, nullable) void(^doubleTapped)(ZFPlayerGestureControl *control);

/// Begin pan gesture callback.
@property (nonatomic, copy, nullable) void(^beganPan)(ZFPlayerGestureControl *control, ZFPanDirection direction, ZFPanLocation location);

/// Pan gesture changing callback.
@property (nonatomic, copy, nullable) void(^changedPan)(ZFPlayerGestureControl *control, ZFPanDirection direction, ZFPanLocation location, CGPoint velocity);

/// End the Pan gesture callback.
@property (nonatomic, copy, nullable) void(^endedPan)(ZFPlayerGestureControl *control, ZFPanDirection direction, ZFPanLocation location);

/// Pinch gesture callback.
@property (nonatomic, copy, nullable) void(^pinched)(ZFPlayerGestureControl *control, float scale);

// 这些都是 readonly. 表明这些都是内部创建的, 不要进行修改.
@property (nonatomic, strong, readonly) UITapGestureRecognizer *singleTap;
@property (nonatomic, strong, readonly) UITapGestureRecognizer *doubleTap;
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *panGR;
@property (nonatomic, strong, readonly) UIPinchGestureRecognizer *pinchGR;

// 实时的更改这几个值, 在回调中可以读取到新的值.
@property (nonatomic, readonly) ZFPanDirection panDirection;
@property (nonatomic, readonly) ZFPanLocation panLocation;
@property (nonatomic, readonly) ZFPanMovingDirection panMovingDirection;

@property (nonatomic) ZFPlayerDisableGestureTypes disableTypes;
@property (nonatomic) ZFPlayerDisablePanMovingDirection disablePanMovingDirection;

/**
 Add  all gestures(singleTap、doubleTap、panGR、pinchGR) to the view.
 */
- (void)addGestureToView:(UIView *)view;

/**
 Remove all gestures(singleTap、doubleTap、panGR、pinchGR) form the view.
 */
- (void)removeGestureToView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
