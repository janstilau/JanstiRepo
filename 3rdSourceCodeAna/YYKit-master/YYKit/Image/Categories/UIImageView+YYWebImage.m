//
//  UIImageView+YYWebImage.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/2/23.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "UIImageView+YYWebImage.h"
#import "YYWebImageOperation.h"
#import "_YYWebImageSetter.h"
#import "YYKitMacro.h"
#import <objc/runtime.h>

YYSYNTH_DUMMY_CLASS(UIImageView_YYWebImage)

static int _YYWebImageSetterKey;
static int _YYWebImageHighlightedSetterKey;


@implementation UIImageView (YYWebImage)

#pragma mark - image

- (NSURL *)imageURL {
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageSetterKey);
    return setter.imageURL;
}

/*
 "setImageWithURL" is conflict to AFNetworking and SDWebImage...WTF!
 So.. We use "setImageURL:" instead.
 */
- (void)setImageURL:(NSURL *)imageURL {
    [self setImageWithURL:imageURL
              placeholder:nil
                  options:kNilOptions
                  manager:nil
                 progress:nil
                transform:nil
               completion:nil];
}

- (void)setImageWithURL:(NSURL *)imageURL placeholder:(UIImage *)placeholder {
    [self setImageWithURL:imageURL
              placeholder:placeholder
                  options:kNilOptions
                  manager:nil
                 progress:nil
                transform:nil
               completion:nil];
}

- (void)setImageWithURL:(NSURL *)imageURL options:(YYWebImageOptions)options {
    [self setImageWithURL:imageURL
              placeholder:nil
                  options:options
                  manager:nil
                 progress:nil
                transform:nil
               completion:nil];
}

- (void)setImageWithURL:(NSURL *)imageURL
            placeholder:(UIImage *)placeholder
                options:(YYWebImageOptions)options
             completion:(YYWebImageCompletionBlock)completion {
    [self setImageWithURL:imageURL
              placeholder:placeholder
                  options:options
                  manager:nil
                 progress:nil
                transform:nil
               completion:completion];
}

- (void)setImageWithURL:(NSURL *)imageURL
            placeholder:(UIImage *)placeholder
                options:(YYWebImageOptions)options
               progress:(YYWebImageProgressBlock)progress
              transform:(YYWebImageTransformBlock)transform
             completion:(YYWebImageCompletionBlock)completion {
    [self setImageWithURL:imageURL
              placeholder:placeholder
                  options:options
                  manager:nil
                 progress:progress
                transform:transform
               completion:completion];
}


// 这个函数, 或者 UIView 层级的工作是, 具体的 image 的赋值的过程.
// 首先是内存中检测, 如果内存中进行了存储, 直接设置显示内容然后返回.
// 然后是生成一个任务, 并且在组装任务的 progress 回调和 completion 回调. 在回调里面, 要检测当初的任务的 id 是否和现在最新的任务 id 是一致的, 不一致代表imageurl 进行了更新.
- (void)setImageWithURL:(NSURL *)imageURL
            placeholder:(UIImage *)placeholder
                options:(YYWebImageOptions)options
                manager:(YYWebImageManager *)manager
               progress:(YYWebImageProgressBlock)progress
              transform:(YYWebImageTransformBlock)transform
             completion:(YYWebImageCompletionBlock)completion {
    if ([imageURL isKindOfClass:[NSString class]]) imageURL = [NSURL URLWithString:(id)imageURL];
    manager = manager ? manager : [YYWebImageManager sharedManager];
    
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageSetterKey);
    if (!setter) {
        setter = [_YYWebImageSetter new];
        objc_setAssociatedObject(self, &_YYWebImageSetterKey, setter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    int32_t sentinel = [setter cancelWithNewURL:imageURL];
    
    dispatch_async_on_main_queue(^{
        if ((options & YYWebImageOptionSetImageWithFadeAnimation) &&
            !(options & YYWebImageOptionAvoidSetImage)) {
            if (!self.highlighted) {
                [self.layer removeAnimationForKey:_YYWebImageFadeAnimationKey];
            }
        }
        
        if (!imageURL) { // imageUrl 数据失效.
            if (!(options & YYWebImageOptionIgnorePlaceHolder)) {
                self.image = placeholder;
            }
            return;
        }
        
        // 首先尝试从内存中取值, 如果图片就在内存中, 直接执行回调然后返回.
        UIImage *imageFromMemory = nil;
        if (manager.cache && // 如果使用了图片缓存.
            !(options & YYWebImageOptionUseNSURLCache) &&
            !(options & YYWebImageOptionRefreshImageCache)) {
            // 读取内存中缓存的图片.
            imageFromMemory = [manager.cache getImageForKey:[manager cacheKeyForURL:imageURL] withType:YYImageCacheTypeMemory];
        }
        if (imageFromMemory) { // 可以取得到内存的图片
            if (!(options & YYWebImageOptionAvoidSetImage)) {
                // 赋值.
                self.image = imageFromMemory;
            }
            // 执行回调.
            if(completion) completion(imageFromMemory, imageURL, YYWebImageFromMemoryCacheFast, YYWebImageStageFinished, nil);
            return;
        }
        
        // 设置占位图片.
        if (!(options & YYWebImageOptionIgnorePlaceHolder)) {
            self.image = placeholder;
        }
        
        __weak typeof(self) _self = self;
        // 在子线程, 执行下载任务.
        dispatch_async([_YYWebImageSetter setterQueue], ^{
            YYWebImageProgressBlock _progress = nil;
            // 如果传入了 progress 回调, 就生成相应的回调. 这里, 专门做一次线程的切换处理.
            if (progress) _progress = ^(NSInteger receivedSize, NSInteger expectedSize) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(receivedSize, expectedSize);
                });
            };
            
            __block int32_t newSentinel = 0;
            __block __weak typeof(setter) weakSetter = nil;
            YYWebImageCompletionBlock _completion = ^(UIImage *image, NSURL *url, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
                __strong typeof(_self) self = _self;
                BOOL setImage = (stage == YYWebImageStageFinished || stage == YYWebImageStageProgress) && image && !(options & YYWebImageOptionAvoidSetImage);
                // 在主线程执行操作.
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL sentinelChanged = weakSetter && weakSetter.sentinel != newSentinel; // 如果当前图片的任务失效了, cancel了 或者 set 了新的 imageUrl
                    if (setImage && self && !sentinelChanged) {
                        BOOL showFade = ((options & YYWebImageOptionSetImageWithFadeAnimation) && !self.highlighted);
                        if (showFade) { // 如果有渐隐效果, 增加动画.
                            CATransition *transition = [CATransition animation];
                            transition.duration = stage == YYWebImageStageFinished ? _YYWebImageFadeTime : _YYWebImageProgressiveFadeTime;
                            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                            transition.type = kCATransitionFade;
                            [self.layer addAnimation:transition forKey:_YYWebImageFadeAnimationKey];
                        }
                        self.image = image; // image 赋值.
                    }
                    if (completion) {
                        if (sentinelChanged) { // 如果任务失效了, completion 的回到传入相应状态
                            completion(nil, url, YYWebImageFromNone, YYWebImageStageCancelled, nil);
                        } else { // 传出现在的 状态.
                            completion(image, url, from, stage, error);
                        }
                    }
                });
            };
            
            newSentinel = [setter setOperationWithSentinel:sentinel url:imageURL options:options manager:manager progress:_progress transform:transform completion:_completion];
            weakSetter = setter;
        });
    });
}

- (void)cancelCurrentImageRequest {
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageSetterKey);
    if (setter) [setter cancel];
}


#pragma mark - highlighted image

- (NSURL *)highlightedImageURL {
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageHighlightedSetterKey);
    return setter.imageURL;
}

- (void)setHighlightedImageURL:(NSURL *)imageURL {
    [self setHighlightedImageWithURL:imageURL
                         placeholder:nil
                             options:kNilOptions
                             manager:nil
                            progress:nil
                           transform:nil
                          completion:nil];
}

- (void)setHighlightedImageWithURL:(NSURL *)imageURL placeholder:(UIImage *)placeholder {
    [self setHighlightedImageWithURL:imageURL
                         placeholder:placeholder
                             options:kNilOptions
                             manager:nil
                            progress:nil
                           transform:nil
                          completion:nil];
}

- (void)setHighlightedImageWithURL:(NSURL *)imageURL options:(YYWebImageOptions)options {
    [self setHighlightedImageWithURL:imageURL
                         placeholder:nil
                             options:options
                             manager:nil
                            progress:nil
                           transform:nil
                          completion:nil];
}

- (void)setHighlightedImageWithURL:(NSURL *)imageURL
                       placeholder:(UIImage *)placeholder
                           options:(YYWebImageOptions)options
                        completion:(YYWebImageCompletionBlock)completion {
    [self setHighlightedImageWithURL:imageURL
                         placeholder:placeholder
                             options:options
                             manager:nil
                            progress:nil
                           transform:nil
                          completion:completion];
}

- (void)setHighlightedImageWithURL:(NSURL *)imageURL
                       placeholder:(UIImage *)placeholder
                           options:(YYWebImageOptions)options
                          progress:(YYWebImageProgressBlock)progress
                         transform:(YYWebImageTransformBlock)transform
                        completion:(YYWebImageCompletionBlock)completion {
    [self setHighlightedImageWithURL:imageURL
                         placeholder:placeholder
                             options:options
                             manager:nil
                            progress:progress
                           transform:nil
                          completion:completion];
}

- (void)setHighlightedImageWithURL:(NSURL *)imageURL
                       placeholder:(UIImage *)placeholder
                           options:(YYWebImageOptions)options
                           manager:(YYWebImageManager *)manager
                          progress:(YYWebImageProgressBlock)progress
                         transform:(YYWebImageTransformBlock)transform
                        completion:(YYWebImageCompletionBlock)completion {
    if ([imageURL isKindOfClass:[NSString class]]) imageURL = [NSURL URLWithString:(id)imageURL];
    manager = manager ? manager : [YYWebImageManager sharedManager];
    
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageHighlightedSetterKey);
    if (!setter) {
        setter = [_YYWebImageSetter new];
        objc_setAssociatedObject(self, &_YYWebImageHighlightedSetterKey, setter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    int32_t sentinel = [setter cancelWithNewURL:imageURL];
    
    dispatch_async_on_main_queue(^{
        if ((options & YYWebImageOptionSetImageWithFadeAnimation) &&
            !(options & YYWebImageOptionAvoidSetImage)) {
            if (self.highlighted) {
                [self.layer removeAnimationForKey:_YYWebImageFadeAnimationKey];
            }
        }
        if (!imageURL) {
            if (!(options & YYWebImageOptionIgnorePlaceHolder)) {
                self.highlightedImage = placeholder;
            }
            return;
        }
        
        // get the image from memory as quickly as possible
        UIImage *imageFromMemory = nil;
        if (manager.cache &&
            !(options & YYWebImageOptionUseNSURLCache) &&
            !(options & YYWebImageOptionRefreshImageCache)) {
            imageFromMemory = [manager.cache getImageForKey:[manager cacheKeyForURL:imageURL] withType:YYImageCacheTypeMemory];
        }
        if (imageFromMemory) {
            if (!(options & YYWebImageOptionAvoidSetImage)) {
                self.highlightedImage = imageFromMemory;
            }
            if(completion) completion(imageFromMemory, imageURL, YYWebImageFromMemoryCacheFast, YYWebImageStageFinished, nil);
            return;
        }
        
        if (!(options & YYWebImageOptionIgnorePlaceHolder)) {
            self.highlightedImage = placeholder;
        }
        
        __weak typeof(self) _self = self;
        dispatch_async([_YYWebImageSetter setterQueue], ^{
            YYWebImageProgressBlock _progress = nil;
            if (progress) _progress = ^(NSInteger receivedSize, NSInteger expectedSize) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(receivedSize, expectedSize);
                });
            };
            
            __block int32_t newSentinel = 0;
            __block __weak typeof(setter) weakSetter = nil;
            YYWebImageCompletionBlock _completion = ^(UIImage *image, NSURL *url, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
                __strong typeof(_self) self = _self;
                BOOL setImage = (stage == YYWebImageStageFinished || stage == YYWebImageStageProgress) && image && !(options & YYWebImageOptionAvoidSetImage);
                BOOL showFade = ((options & YYWebImageOptionSetImageWithFadeAnimation) && self.highlighted);
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL sentinelChanged = weakSetter && weakSetter.sentinel != newSentinel;
                    if (setImage && self && !sentinelChanged) {
                        if (showFade) {
                            CATransition *transition = [CATransition animation];
                            transition.duration = stage == YYWebImageStageFinished ? _YYWebImageFadeTime : _YYWebImageProgressiveFadeTime;
                            transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                            transition.type = kCATransitionFade;
                            [self.layer addAnimation:transition forKey:_YYWebImageFadeAnimationKey];
                        }
                        self.highlightedImage = image;
                    }
                    if (completion) {
                        if (sentinelChanged) {
                            completion(nil, url, YYWebImageFromNone, YYWebImageStageCancelled, nil);
                        } else {
                            completion(image, url, from, stage, error);
                        }
                    }
                });
            };
            
            newSentinel = [setter setOperationWithSentinel:sentinel url:imageURL options:options manager:manager progress:_progress transform:transform completion:_completion];
            weakSetter = setter;
        });
    });
}

- (void)cancelCurrentHighlightedImageRequest {
    _YYWebImageSetter *setter = objc_getAssociatedObject(self, &_YYWebImageHighlightedSetterKey);
    if (setter) [setter cancel];
}

@end
