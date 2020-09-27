/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "SDWebImageError.h"
#import "SDInternalMacros.h"
#import "SDWebImageTransitionInternal.h"

const int64_t SDWebImageProgressUnitCountUnknown = 1LL;

/*
 对于 View 来说, 他就是
 */

@implementation UIView (WebCache)

/*
 当前的 url, 是通过关联对象的技术, 绑定到了 UIView 对象上面.
 */
- (nullable NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, @selector(sd_imageURL));
}

- (void)setSd_imageURL:(NSURL * _Nullable)sd_imageURL {
    objc_setAssociatedObject(self, @selector(sd_imageURL), sd_imageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable NSString *)sd_latestOperationKey {
    return objc_getAssociatedObject(self, @selector(sd_latestOperationKey));
}

- (void)setSd_latestOperationKey:(NSString * _Nullable)sd_latestOperationKey {
    objc_setAssociatedObject(self, @selector(sd_latestOperationKey), sd_latestOperationKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSProgress *)sd_imageProgress {
    NSProgress *progress = objc_getAssociatedObject(self, @selector(sd_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.sd_imageProgress = progress;
    }
    return progress;
}

- (void)setSd_imageProgress:(NSProgress *)sd_imageProgress {
    objc_setAssociatedObject(self, @selector(sd_imageProgress), sd_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                           context:(nullable SDWebImageContext *)context
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDImageLoaderProgressBlock)progressBlock
                         completed:(nullable SDInternalCompletionBlock)completedBlock {
    if (context) {
        // copy to avoid mutable object, 这里, 框架会更多的考虑安全.
        context = [context copy];
    } else {
        context = [NSDictionary dictionary];
    }
    NSString *validOperationKey = context[SDWebImageContextSetImageOperationKey];
    if (!validOperationKey) {
        // pass through the operation key to downstream, which can used for tracing operation or image view class
        validOperationKey = NSStringFromClass([self class]);
        SDWebImageMutableContext *mutableContext = [context mutableCopy];
        mutableContext[SDWebImageContextSetImageOperationKey] = validOperationKey;
        context = [mutableContext copy];
    }
    self.sd_latestOperationKey = validOperationKey;
    /*
     在 sd_cancelImageLoadOperationWithKey 的内部, 会有着对于原有的 url 下载的取消操作.
     在 MOCA 原来的设计里面, 没有取消操作, 只是在下载完之后, 发现 url 不一致了, 就认为是 view 设置了新的 url 代表的 image, 从而不再进行 Image 的设置. 而 SD 中, 专门有了 operation 的 cancle 操作.
     这里, 有一个明确的 cancel 还是挺重要的. 如果需要下载, 那么会占用网络资源的. 取消已经不再需要的网络下载, 可以让当前设置 image, 可以优先进行下载.
     之前 MOCA 还专门进行了下载任务的调度处理. 目前来看, 取消已经不需要的图片下载的策略更好.
     */
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];
    /*
     首先, 要记录一下, 当前正在下载的 url, 防止 View 被复用的使用, 产生数据的紊乱问题.
     */
    self.sd_imageURL = url;
    
    /*
     默认, 是如果设置了 占位图, 就立马设置上去.
     如果 options 里面, 显式取消的话, 才会延迟这个操作, 延迟到图片下载完成之后, 才进行占位图的设置.
     */
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:SDImageCacheTypeNone imageURL:url];
        });
    }
    
    if (url) {
        // reset the progress
        NSProgress *imageProgress = objc_getAssociatedObject(self, @selector(sd_imageProgress));
        if (imageProgress) {
            imageProgress.totalUnitCount = 0;
            imageProgress.completedUnitCount = 0;
        }
        
        [self sd_startImageIndicator];
        id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
        
        SDWebImageManager *manager = context[SDWebImageContextCustomManager];
        if (!manager) {
            manager = [SDWebImageManager sharedManager];
        } else {
            // remove this manager to avoid retain cycle (manger -> loader -> operation -> context -> manager)
            SDWebImageMutableContext *mutableContext = [context mutableCopy];
            mutableContext[SDWebImageContextCustomManager] = nil;
            context = [mutableContext copy];
        }
        
        /*
         这是一个 progress 相关的闭包. 在里面, 是调用 imageIndicator 的 UI 层面的更新方法, 以及 progressBlock 的调用.
         */
        SDImageLoaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize,
                                                             NSInteger expectedSize,
                                                             NSURL * _Nullable targetURL) {
            if (imageProgress) {
                imageProgress.totalUnitCount = expectedSize;
                imageProgress.completedUnitCount = receivedSize;
            }
            
            if ([imageIndicator respondsToSelector:@selector(updateIndicatorProgress:)]) {
                double progress = 0;
                if (expectedSize != 0) {
                    progress = (double)receivedSize / expectedSize;
                }
                progress = MAX(MIN(progress, 1), 0); // 0.0 - 1.0
                dispatch_async(dispatch_get_main_queue(), ^{
                    [imageIndicator updateIndicatorProgress:progress];
                });
            }
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        
        /*
         所有的数据, 包括 progress 的回调, 都被当做数据传递到 manager 的内部. 由 Manager 进行最终的调度处理.
         completed 里面的参数, 可能不会全部用到, 但是给出来的是最全的数据.
         */
        @weakify(self);
        id <SDWebImageOperation> operation = [manager loadImageWithURL:url
                                                               options:options
                                                               context:context
                                                              progress:combinedProgressBlock
                                                             completed:^(UIImage *image,
                                                                         NSData *data,
                                                                         NSError *error,
                                                                         SDImageCacheType cacheType,
                                                                         BOOL finished,
                                                                         NSURL *imageURL) {
            /*
             能来到这里, 证明图片资源的下载, 图片资源的解析, 缓存, 图片的生成等各种操作, 都已经完成, 只剩下最后的赋值处理了.
             */
            /*
             这里, 如果 self 不存在, 证明 self view 已经从屏幕上消失了. 所以也就没有了更新 image 的必要了.
             */
            @strongify(self);
            if (!self) { return; }
            // if the progress not been updated, mark it to complete state
            if (imageProgress && finished && !error && imageProgress.totalUnitCount == 0 && imageProgress.completedUnitCount == 0) {
                imageProgress.totalUnitCount = SDWebImageProgressUnitCountUnknown;
                imageProgress.completedUnitCount = SDWebImageProgressUnitCountUnknown;
            }
            
#if SD_UIKIT || SD_MAC
            // check and stop image indicator
            if (finished) {
                [self sd_stopImageIndicator];
            }
#endif
            
            BOOL shouldCallCompletedBlock = finished || (options & SDWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & SDWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & SDWebImageDelayPlaceholder)));
            /*
             如果有复用的可能性, 提前定义 block 变量, 供下方使用.
             这里, 将这些在外界进行方法的抽离, 也有些问题.
             这些逻辑, 完完全全是依附在该方法内部, 将逻辑提升到类的层次, 会让类的使用者感到类不好用.
             */
            SDWebImageNoParamsBlock callCompletedBlockClojure = ^{
                if (!self) { return; }
                if (!shouldNotSetImage) {
                    [self sd_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, data, error, cacheType, finished, url);
                }
            };
            
            // case 1a: we got an image, but the SDWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the SDWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the SDWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & SDWebImageDelayPlaceholder) {
                // case 2b: we got no image and the SDWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if SD_UIKIT || SD_MAC
            // check whether we should use the image transition
            SDWebImageTransition *transition = nil;
            BOOL shouldUseTransition = NO;
            /*
             cacheType 这里可以看出来, 这个值, 并不是说 url 对应的图片应不应该缓存, 而是读取到的 image 数据, 是不是用缓存里面获取到的.
             下面各种情况, 都是在判断, 这次 view 的 image 更新, 应不应该进行转成动画.
             */
            if (options & SDWebImageForceTransition) {
                // Always
                shouldUseTransition = YES;
            } else if (cacheType == SDImageCacheTypeNone) {
                // From network
                shouldUseTransition = YES;
            } else {
                // From disk (and, user don't use sync query)
                if (cacheType == SDImageCacheTypeMemory) {
                    shouldUseTransition = NO;
                } else if (cacheType == SDImageCacheTypeDisk) {
                    if (options & SDWebImageQueryMemoryDataSync || options & SDWebImageQueryDiskDataSync) {
                        shouldUseTransition = NO;
                    } else {
                        shouldUseTransition = YES;
                    }
                } else {
                    // Not valid cache type, fallback
                    shouldUseTransition = NO;
                }
            }
            if (finished && shouldUseTransition) {
                transition = self.sd_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
                [self sd_setImage:targetImage
                        imageData:targetData
basedOnClassOrViaCustomSetImageBlock:setImageBlock
                       transition:transition
                        cacheType:cacheType
                         imageURL:imageURL];
                callCompletedBlockClojure();
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        /*
         停止 loading 并报错.
         */
        [self sd_stopImageIndicator];
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain
                                                     code:SDWebImageErrorInvalidURL
                                                 userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
                completedBlock(nil, nil, error, SDImageCacheTypeNone, YES, url);
            }
        });
    }
}

- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:self.sd_latestOperationKey];
    self.sd_latestOperationKey = nil;
}

- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock cacheType:(SDImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    [self sd_setImage:image
            imageData:imageData
basedOnClassOrViaCustomSetImageBlock:setImageBlock
           transition:nil
            cacheType:cacheType
             imageURL:imageURL];
}

/*
 这里是, 是最终, 将 Image 设置到 View 上的代码.
 这里, 其实后面两个参数, 不会真正的用到, 但是还是传递了过来了.
 */
- (void)sd_setImage:(UIImage *)image
          imageData:(NSData *)imageData
basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock
         transition:(SDWebImageTransition *)transition
          cacheType:(SDImageCacheType)cacheType
           imageURL:(NSURL *)imageURL {
    UIView *view = self;
    SDSetImageBlock finalSetImageBlock;
    /*
     setImageBlock 就是获取到 UIImage 之后, 应该怎么处理.
     这里, 有了一些简化的处理, 就是判断类型, 如果 UIImageView, 或者 UIButton 的话, 就进行默认的操作.
     */
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
    
    if (transition) {
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            // sd_latestOperationKey 为空, 代表着 view 的当前 setImage 取消了. 所以, 在各个阶段, 都对这个值进行了判断.
            if (!view.sd_latestOperationKey) {
                return;
            }
            /*
             如果, transition 中设置了 prepares, 那么就先执行一下.
             可以看到, 成熟的类库, 有着各种各样的自定义的埋点在这里, 但是作为使用者, 一定是使用类库最重要的功能.
             所以, 这些埋点大部分情况下不会进行执行.
             */
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL finished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                // sd_latestOperationKey 为空, 代表着 view 的当前 setImage 取消了. 所以, 在各个阶段, 都对这个值进行了判断.
                if (!view.sd_latestOperationKey) {
                    return;
                }
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:^(BOOL finished) {
                // sd_latestOperationKey 为空, 代表着 view 的当前 setImage 取消了. 所以, 在各个阶段, 都对这个值进行了判断.
                if (!view.sd_latestOperationKey) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(finished);
                }
            }];
        }];
    } else {
        // 如果不需要转场动画, 直接就是 iamge 的设置工作.
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData, cacheType, imageURL);
        }
    }
}

- (void)sd_setNeedsLayout {
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#elif SD_WATCH
    // Do nothing because WatchKit automatically layout the view after property change
#endif
}

#if SD_UIKIT || SD_MAC

#pragma mark - Image Transition
- (SDWebImageTransition *)sd_imageTransition {
    return objc_getAssociatedObject(self, @selector(sd_imageTransition));
}

- (void)setSd_imageTransition:(SDWebImageTransition *)sd_imageTransition {
    objc_setAssociatedObject(self, @selector(sd_imageTransition), sd_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Indicator
- (id<SDWebImageIndicator>)sd_imageIndicator {
    return objc_getAssociatedObject(self, @selector(sd_imageIndicator));
}

/*
 这里, set 方法内部, 将 indicator 的 indicatorView 添加到了 self 的 view hierarchy 上.
 */
- (void)setSd_imageIndicator:(id<SDWebImageIndicator>)sd_imageIndicator {
    // Remove the old indicator view
    id<SDWebImageIndicator> previousIndicator = self.sd_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];
    
    objc_setAssociatedObject(self, @selector(sd_imageIndicator), sd_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add the new indicator view
    UIView *view = sd_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if SD_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = NO;
    [self addSubview:view];
}

/*
 这两个函数, 就是调用 imageIndicator 的 start, stop 方法.
 这两个方法, 可以算作是 高层模块, 对于底层模块接口的兼容使用.
 */
- (void)sd_startImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator startAnimatingIndicator];
    });
}

- (void)sd_stopImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator stopAnimatingIndicator];
    });
}

#endif

@end
