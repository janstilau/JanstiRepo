/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"

#if SD_UIKIT || SD_MAC

/*
 A protocol to custom the indicator during the image loading.
 All of these methods are called from main queue.
 */
/*
 这个协议, 是属于低层次模块的. 也就是说, 高层次模块, 要使用这个协议, 就要按照低层次模块的设计来进行使用.
 相应的, 什么时候, 应该调用什么方法, 应该按照低层次模块的要求.
 比如, 低层次模块规定, 在开始进行下载的时候, 调用 startAnimatingIndicator, 那么高层次模块, 就要在合适的时机, 去调用该方法.
 而高层次模块产生的接口, 则是高层次模块自己设计, 什么时候应该调用哪些接口, 而低层次模块, 要尽力去配合实现这些接口.
 */
/*
 这个协议, 也是非常简单的
 一个 indicatorView , 进行进度展示.
 开始
 结束
 更新
 */
@protocol SDWebImageIndicator <NSObject>

@required
/**
 The view associate to the indicator.

 @return The indicator view
 */
@property (nonatomic, strong, readonly, nonnull) UIView *indicatorView;

/**
 Start the animating for indicator.
 */
- (void)startAnimatingIndicator;

/**
 Stop the animating for indicator.
 */
- (void)stopAnimatingIndicator;

@optional
/**
 Update the loading progress (0-1.0) for indicator. Optional
 
 @param progress The progress, value between 0 and 1.0
 */
- (void)updateIndicatorProgress:(double)progress;

@end

#pragma mark - Activity Indicator

/**
 Activity indicator class.
 for UIKit(macOS), it use a `UIActivityIndicatorView`.
 for AppKit(macOS), it use a `NSProgressIndicator` with the spinning style.
 */
@interface SDWebImageActivityIndicator : NSObject <SDWebImageIndicator>

@property (nonatomic, strong, readonly, nonnull) UIActivityIndicatorView *indicatorView;

@end

/**
 Convenience way to use activity indicator.
 */
@interface SDWebImageActivityIndicator (Conveniences)

/*
 有了 Class property 之后, 类库开始大量使用该方式, 去定义工厂方法.
 */

/// These indicator use the fixed color without dark mode support
/// gray-style activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *grayIndicator;
/// large gray-style activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *grayLargeIndicator;
/// white-style activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *whiteIndicator;
/// large white-style activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *whiteLargeIndicator;
/// These indicator use the system style, supports dark mode if available (iOS 13+/macOS 10.14+)
/// large activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *largeIndicator;
/// medium activity indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageActivityIndicator *mediumIndicator;

@end

#pragma mark - Progress Indicator

/*
 Progress indicator class.
 for UIKit(macOS), it use a `UIProgressView`.
 */
@interface SDWebImageProgressIndicator : NSObject <SDWebImageIndicator>

#if SD_UIKIT
@property (nonatomic, strong, readonly, nonnull) UIProgressView *indicatorView;
#else
@property (nonatomic, strong, readonly, nonnull) NSProgressIndicator *indicatorView;
#endif

@end

/**
 Convenience way to create progress indicator. Remember to specify the indicator width or use layout constraint if need.
 */
@interface SDWebImageProgressIndicator (Conveniences)

/// default-style progress indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageProgressIndicator *defaultIndicator;
/// bar-style progress indicator
@property (nonatomic, class, nonnull, readonly) SDWebImageProgressIndicator *barIndicator API_UNAVAILABLE(macos, tvos);

@end

#endif
