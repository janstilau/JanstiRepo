#import <UIKit/UIKit.h>
#import "ZFSliderView.h"
#if __has_include(<ZFPlayer/ZFPlayerController.h>)
#import <ZFPlayer/ZFPlayerController.h>
#else
#import "ZFPlayerController.h"
#endif

NS_ASSUME_NONNULL_BEGIN

// 横屏全屏的控制界面. 在回复之后, 消失.

@interface ZFLandScapeControlView : UIView

// 所有的都是 readonly. 所以, 这些 view 都是内部生成, 暴露给外界进行调用的.

/// 顶部工具栏
@property (nonatomic, strong, readonly) UIView *topToolView;

/// 返回按钮
@property (nonatomic, strong, readonly) UIButton *backBtn;

/// 标题
@property (nonatomic, strong, readonly) UILabel *titleLabel;

/// 底部工具栏
@property (nonatomic, strong, readonly) UIView *bottomToolView;

/// 播放或暂停按钮 
@property (nonatomic, strong, readonly) UIButton *playOrPauseBtn;

/// 播放的当前时间
@property (nonatomic, strong, readonly) UILabel *currentTimeLabel;

/// 滑杆
@property (nonatomic, strong, readonly) ZFSliderView *slider;

/// 视频总时间
@property (nonatomic, strong, readonly) UILabel *totalTimeLabel;

/// 锁定屏幕按钮
@property (nonatomic, strong, readonly) UIButton *lockBtn;

/// 播放器, 这里, 直接把播放器暴露出来了. 让视图直接可以进行 player 的调用.
@property (nonatomic, weak) ZFPlayerController *player;

/// slider滑动中
@property (nonatomic, copy, nullable) void(^sliderValueChanging)(CGFloat value,BOOL forward);

/// slider滑动结束
@property (nonatomic, copy, nullable) void(^sliderValueChanged)(CGFloat value);

/// 返回按钮点击回调
@property (nonatomic, copy) void(^backBtnClickCallback)(void);

/// 如果是暂停状态，seek完是否播放，默认YES
@property (nonatomic, assign) BOOL seekToPlay;


// 以下的这些方法, 都是外界调用的. 都是为了控制这个 View 的显示效果.
/// 重置控制层
- (void)resetControlView;

/// 显示控制层
- (void)showControlView;

/// 隐藏控制层
- (void)hideControlView;

/// 设置播放时间
- (void)videoPlayer:(ZFPlayerController *)videoPlayer currentTime:(NSTimeInterval)currentTime totalTime:(NSTimeInterval)totalTime;

/// 设置缓冲时间
- (void)videoPlayer:(ZFPlayerController *)videoPlayer bufferTime:(NSTimeInterval)bufferTime;

/// 是否响应该手势
- (BOOL)shouldResponseGestureWithPoint:(CGPoint)point withGestureType:(ZFPlayerGestureType)type touch:(nonnull UITouch *)touch;

/// 视频尺寸改变
- (void)videoPlayer:(ZFPlayerController *)videoPlayer presentationSizeChanged:(CGSize)size;

/// 标题和全屏模式
- (void)showTitle:(NSString *_Nullable)title fullScreenMode:(ZFFullScreenMode)fullScreenMode;

/// 根据当前播放状态取反
- (void)playOrPause;

/// 播放按钮状态
- (void)playBtnSelectedState:(BOOL)selected;

/// 调节播放进度slider和当前时间更新
- (void)sliderValueChanged:(CGFloat)value currentTimeString:(NSString *)timeString;

/// 滑杆结束滑动
- (void)sliderChangeEnded;

@end

NS_ASSUME_NONNULL_END