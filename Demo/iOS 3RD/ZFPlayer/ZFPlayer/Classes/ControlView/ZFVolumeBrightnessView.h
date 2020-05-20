#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ZFVolumeBrightnessType) {
    ZFVolumeBrightnessTypeVolume,       // volume
    ZFVolumeBrightnessTypeumeBrightness // brightness
};

@interface ZFVolumeBrightnessView : UIView

@property (nonatomic, assign, readonly) ZFVolumeBrightnessType volumeBrightnessType;
@property (nonatomic, strong, readonly) UIProgressView *progressView;
@property (nonatomic, strong, readonly) UIImageView *iconImageView;

- (void)updateProgress:(CGFloat)progress withVolumeBrightnessType:(ZFVolumeBrightnessType)volumeBrightnessType;

/// 添加系统音量view
- (void)addSystemVolumeView;

/// 移除系统音量view
- (void)removeSystemVolumeView;

@end
