#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * The scroll direction of scrollView.
 */
typedef NS_ENUM(NSUInteger, ZFPlayerScrollDirection) {
    ZFPlayerScrollDirectionNone,
    ZFPlayerScrollDirectionUp,         // Scroll up
    ZFPlayerScrollDirectionDown,       // Scroll Down
    ZFPlayerScrollDirectionLeft,       // Scroll left
    ZFPlayerScrollDirectionRight       // Scroll right
};

/*
 * The scrollView direction.
 */
typedef NS_ENUM(NSInteger, ZFPlayerScrollViewDirection) {
    ZFPlayerScrollViewDirectionVertical,
    ZFPlayerScrollViewDirectionHorizontal
};

/*
 * The player container type
 */
typedef NS_ENUM(NSInteger, ZFPlayerContainerType) {
    ZFPlayerContainerTypeView, // 专门一个 view 播放视频.
    ZFPlayerContainerTypeCell // Cell 中播放视频
};

@interface UIScrollView (ZFPlayer)

/// When the ZFPlayerScrollViewDirection is ZFPlayerScrollViewDirectionVertical,the property has value.
@property (nonatomic, readonly) CGFloat zf_lastOffsetY;

/// When the ZFPlayerScrollViewDirection is ZFPlayerScrollViewDirectionHorizontal,the property has value.
@property (nonatomic, readonly) CGFloat zf_lastOffsetX;

/// The scrollView scroll direction, default is ZFPlayerScrollViewDirectionVertical.
@property (nonatomic) ZFPlayerScrollViewDirection zf_scrollViewDirection;

/// The scroll direction of scrollView while scrolling.
/// When the ZFPlayerScrollViewDirection is ZFPlayerScrollViewDirectionVertical，this value can only be ZFPlayerScrollDirectionUp or ZFPlayerScrollDirectionDown.
/// When the ZFPlayerScrollViewDirection is ZFPlayerScrollViewDirectionVertical，this value can only be ZFPlayerScrollDirectionLeft or ZFPlayerScrollDirectionRight.
@property (nonatomic, readonly) ZFPlayerScrollDirection zf_scrollDirection;

/// Get the cell according to indexPath.
- (UIView *)zf_getCellForIndexPath:(NSIndexPath *)indexPath;

/// Get the indexPath for cell.
- (NSIndexPath *)zf_getIndexPathForCell:(UIView *)cell;

/// Scroll to indexPath with animations.
- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath completionHandler:(void (^ __nullable)(void))completionHandler;

/// add in 3.2.4 version.
/// Scroll to indexPath with animations.
- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated completionHandler:(void (^ __nullable)(void))completionHandler;

/// add in 3.2.8 version.
/// Scroll to indexPath with animations duration.
- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath animateWithDuration:(NSTimeInterval)duration completionHandler:(void (^ __nullable)(void))completionHandler;

///------------------------------------
/// The following method must be implemented in UIScrollViewDelegate.
///------------------------------------

- (void)zf_scrollViewDidEndDecelerating;

- (void)zf_scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate;

- (void)zf_scrollViewDidScrollToTop;

- (void)zf_scrollViewDidScroll;

- (void)zf_scrollViewWillBeginDragging;

///------------------------------------
/// end
///------------------------------------


@end

@interface UIScrollView (ZFPlayerCannotCalled)

/*
 这个分类里面, 提供了各种各样的时机回调, 真正对于 player 的切换, 应该是放到各个回调的内部. ScrollView, 作为视图, 并没有提供直接控制 player 的方法.
 */

// 各种时机的回调, 都传递出去了, 由外界来做各个事件的自定义工作.
/// The block invoked When the player appearing.
@property (nonatomic, copy, nullable) void(^zf_playerAppearingInScrollView)(NSIndexPath *indexPath, CGFloat playerApperaPercent);

/// The block invoked When the player disappearing.
@property (nonatomic, copy, nullable) void(^zf_playerDisappearingInScrollView)(NSIndexPath *indexPath, CGFloat playerDisapperaPercent);

/// The block invoked When the player will appeared.
@property (nonatomic, copy, nullable) void(^zf_playerWillAppearInScrollView)(NSIndexPath *indexPath);

/// The block invoked When the player did appeared.
@property (nonatomic, copy, nullable) void(^zf_playerDidAppearInScrollView)(NSIndexPath *indexPath);

/// The block invoked When the player will disappear.
@property (nonatomic, copy, nullable) void(^zf_playerWillDisappearInScrollView)(NSIndexPath *indexPath);

/// The block invoked When the player did disappeared.
@property (nonatomic, copy, nullable) void(^zf_playerDidDisappearInScrollView)(NSIndexPath *indexPath);

/// The block invoked When the player did stop scroll.
@property (nonatomic, copy, nullable) void(^zf_scrollViewDidEndScrollingCallback)(NSIndexPath *indexPath);

/// The block invoked When the player did  scroll.
@property (nonatomic, copy, nullable) void(^zf_scrollViewDidScrollCallback)(NSIndexPath *indexPath);

/// The block invoked When the player should play.
// 当, 赋值 shouldPlayIndex 的时候, 会调用这个方法.
// 作者的命名和调用设计有问题.
@property (nonatomic, copy, nullable) void(^zf_playerShouldPlayInScrollView)(NSIndexPath *indexPath);

/// The current player scroll slides off the screen percent.
/// the property used when the `stopWhileNotVisible` is YES, stop the current playing player.
/// the property used when the `stopWhileNotVisible` is NO, the current playing player add to small container view.
/// 0.0~1.0, defalut is 0.5.
/// 0.0 is the player will disappear.
/// 1.0 is the player did disappear.
@property (nonatomic) CGFloat zf_playerDisapperaPercent;

/// The current player scroll to the screen percent to play the video.
/// 0.0~1.0, defalut is 0.0.
/// 0.0 is the player will appear.
/// 1.0 is the player did appear.
@property (nonatomic) CGFloat zf_playerApperaPercent;

/// The current player controller is disappear, not dealloc
@property (nonatomic) BOOL zf_hiddenOnWindow;

/// Has stopped playing
@property (nonatomic, assign) BOOL zf_stopPlay;

/// The currently playing cell stop playing when the cell has out off the screen，defalut is YES.
@property (nonatomic, assign) BOOL zf_stopWhileNotVisible;

/// The indexPath is playing.
// 这个 IndexPath 不会在 ScrollView 中进行复制, 而是由外界传入. 也就是外界设置播放的切换之后, 同步状态到 ScrollView 中.
@property (nonatomic, nullable) NSIndexPath *zf_playingIndexPath;

/// The indexPath should be play while scrolling.
// 这个 IndexPath 会在 ScrollView 的内部不断的进行设值操作, 然后会不断的触发 zf_playerShouldPlayInScrollView 这个回调. 如果想要跟着滑动切换播放的话, 需要设置这个回调.
@property (nonatomic, nullable) NSIndexPath *zf_shouldPlayIndexPath;

/// WWANA networks play automatically,default NO.
@property (nonatomic, getter=zf_isWWANAutoPlay) BOOL zf_WWANAutoPlay;

/// The player should auto player,default is YES.
@property (nonatomic) BOOL zf_shouldAutoPlay;

/// The view tag that the player display in scrollView.
@property (nonatomic) NSInteger zf_containerViewTag;

/// The video contrainerView in normal model.
@property (nonatomic, strong) UIView *zf_containerView;


/// The video contrainerView type.
@property (nonatomic, assign) ZFPlayerContainerType zf_containerType;


/// Filter the cell that should be played when the scroll is stopped (to play when the scroll is stopped).
- (void)zf_findShouldPlayIndexWhenStopped:(void (^ __nullable)(NSIndexPath *indexPath))handler;

/// Filter the cell that should be played while scrolling (you can use this to filter the highlighted cell).
- (void)zf_findShouldPlayIndexWhenScrolling:(void (^ __nullable)(NSIndexPath *indexPath))handler;

@end

NS_ASSUME_NONNULL_END