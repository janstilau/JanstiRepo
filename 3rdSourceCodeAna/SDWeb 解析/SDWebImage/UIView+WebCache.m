/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"

#if SD_UIKIT || SD_MAC

#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"

static char imageURLKey;

#if SD_UIKIT
static char TAG_ACTIVITY_INDICATOR;
static char TAG_ACTIVITY_STYLE;
#endif
static char TAG_ACTIVITY_SHOW;

@implementation UIView (WebCache)

/* 想一下之前 US 的 image 缓存策略. US 的 iamge 分为了 View 层, Image 层, Data 层.
 其中 data 层做的是数据相关的部分, 查询 disk 里面有没有url 对应的 data, 没有的话, 就包装一下, 提交给 AFN 做下载操作. 在 AFN 的下载 progress 和 complete 回调中, 读取包装的数据里面的 progress 和 complete 回调.
 但是 data 层里面的 progress 和 complete 回调, 其实是包含了上面两个层的对调了. 也就是说, 其中包含着函数调用. data的处理逻辑是取得 Data, 而这个取 data 的过程, 和 Image 层无关, 无论是 disk取值, 还是网络取值, 最终都是取得 Data 数据. 在取得 data 数据之后, 调用 Image 层设置的回调.
 到了 image 层, image 层的处理逻辑是, 将 data 的数据进行加工, 构造出一个 UIImage 对象过来, 然后添加到内存缓存中取. 然后将 image 传入到 view 的回调中.
 view 层的逻辑是, 拿到 image, 赋值到自己的 image 属性中, 使得 UI 进行刷新. 这个时候, US 在这里做了一些界面相关的处理. 就是 在 data 层如果发现数据是网络下载的, 就进行一个关联Bool 值, 标志其实是网络得到的值, view 这里会根据这个值, 进行一个动画, 就是一个渐隐效果.
 每一层都只关心自己的那一部分逻辑, 拿到自己需要的值, 做自己那一部分操作. 但是这些操作其实是有着调用关系的, 但是每一层只用关心自己的事情了. 闭包有一个作用, 就是延后执行. A -> B -> C , 这是操作的顺序, 但是通过闭包之后, 我们可以吧 C 党委一个单位给 B, 然后 B 在适当的时候执行它就可以了. 而 B 也可以当做一个单位, 传递给 A. 这样, 还是 A 执行, B 执行, C 执行, 不过我们写代码的时候, 可以只在 C 的代码里面, 写 B 执行, 需要 C 定义的 block. 而不管 B 怎么得到 C 需要的值, 它可能是需要 A 执行, 操作 A 执行的结果生成 C 所定义的值, 但是这都在 B 的定义中, 和 C 无关. 闭包可以造成逻辑的分层, 这对于处理复杂逻辑是非常重要的.
 */

- (nullable NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, &imageURLKey);
}

// 这个函数必然是在主线程执行的. 如果不是在主线程, 那么就是调用者的锅. 任何 UI 操作都必须在主线程
// 这是 view 层的操作, 这里, view 的操作主要是管理 opertation, 或者说取消之前的 operation.
// 具体的取图的操作, 是 manager 的 load 方法.
- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock {
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];
    // 首先, 是每一个 UIView 都是自己的 operation 缓存. 对于像 UIImageView 来说, 一般只有一张图片展示. 但是它也有这 animationImages 这样的特例, 所以在 UIImageView 的分类里面, 其实是有着关于 animationImages 的key. 而对于 UIbutton 来说, 他有着很多的状态, 并且有着 image 和 backgroundImage 两个图片.
    // 所以 operation 需要用 Key 进行管理. 如果只有一张图片会展示在 UIView 上, 那么在设置了新的图片的时候, 自然可以将原来的进行取消了. 但是 UIButton 下载 highlight 的状态图片, 和设置 UIButtonNormal 的状态图片是没有关系, 原来 highlihgt 的任务还应该继续执行. 所以, 而在 UIButton 的分类里面, 明确的看到了根据状态的不同, 生成了不同的 key 值.
    // 所以, sd image 的策略是, 如果是一个 UIView 的同一个 key 被重新赋值了,  那么之前的操作就取消了. 不是一个 key, 还继续下载.
    // 在 US 自定义的图片下载模块里面, 是没有取消一说的. 所以, 所有的下载任务, 都是会执行的. 不过, 他有着优先级一说.
    // 这里, 这样关联的意义是什么
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 这里, options 的取值就是用 & 运算. 如果不推迟显示 placeHolderImage, 就立马设置.
    // 所谓的 placeholder, 其实就是在 url 所在图下来之前, 设置显示的图片.
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
        });
    }
    
    if (url) {
        // 通过关联对象的方式, 增加了一个菊花.
        if ([self sd_showActivityIndicatorView]) {
            [self sd_addActivityIndicator];
        }
        
        __weak __typeof(self)wself = self;
        // 主要的下图的逻辑, 被包装包了 SDWebImageManager 中间.
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager loadImageWithURL:url options:options progress:progressBlock completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            // 这里必然会在主线程执行. 这是在 loadImageWithURL 中调度过来的. 在 loadImageWithURL 中, 首先会做一部分判断, 比如 url 路径问题, 然后会调用 imageWebCache 的查询缓存的方法: 如果内存中有图片, 就直接在主线程中调用这个回调; 否则, 会异步加载 disk 里面的图片, 将图片缓存到内存中, 然后在主线程中, 执行回调.
            // 这里其实能够解释, 为什么 operation , 包括里面的 cacheOperation 仅仅是作为一个数据类存在的. NSOperation, 作为一个封装了操作的类, 必然需要将操作封装到自己的类定义里面才行. 而 GCD 却可以说, 随意的写 block, 并且可以随意的切换线程执行的位置. 这对于编程人员来说, 实在是太方便了.
            __strong __typeof (wself) sself = wself;
            [sself sd_removeActivityIndicator];
            if (!sself) { // 如果 sself 消失了, 就不执行回调了, 但是这里图片是已经下完了. 所以, 下载过程还是会用掉流量.
                // 前面取消, 只是在 cell 复用的时候, cell 设置了新的图片, 那么原来的下载任务就可以取消. 但是 cell 消失了, 回调会不会执行了, 但是下载任务还是会执行.
                return;
            }
            dispatch_main_async_safe(^{
                if (!sself) {
                    return;
                }
                if (image && (options & SDWebImageAvoidAutoSetImage) && completedBlock) {
                    // AvoidAutoSetImage 就是自己手动设置 image 显示到界面上.
                    completedBlock(image, error, cacheType, url);
                    return;
                } else if (image) {
                    // 设置到界面上. 这里并没有进行校验, 就是这个 view 现在显示的图片是不是和下载完的图片的 url 是一样的.  因为一个 view 可能会被设置多次 url 下载任务. 是不是和取消操作有关系, 保证到这里, 一定是 url 匹配的.
                    [sself sd_setImage:image imageData:data basedOnClassOrViaCustomSetImageBlock:setImageBlock];
                    [sself sd_setNeedsLayout];
                } else {
                    if ((options & SDWebImageDelayPlaceholder)) {
                        [sself sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
                        [sself sd_setNeedsLayout];
                    }
                }
                if (completedBlock && finished) {
                    completedBlock(image, error, cacheType, url);
                }
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        dispatch_main_async_safe(^{
            [self sd_removeActivityIndicator];
            if (completedBlock) {
                // 这里, error 里面, 将原因写的清清楚楚.
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock {
    if (setImageBlock) {
        setImageBlock(image, imageData);
        return;
    }
    
#if SD_UIKIT || SD_MAC
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        imageView.image = image;
    }
#endif
    
#if SD_UIKIT
    if ([self isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)self;
        [button setImage:image forState:UIControlStateNormal];
    }
#endif
}

- (void)sd_setNeedsLayout {
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#endif
}

#pragma mark - Activity indicator


// 框架里面用了大量的关联对象, 来为 UIKit 的原有类进行扩展.
#pragma mark -
#if SD_UIKIT
- (UIActivityIndicatorView *)activityIndicator {
    return (UIActivityIndicatorView *)objc_getAssociatedObject(self, &TAG_ACTIVITY_INDICATOR);
}

- (void)setActivityIndicator:(UIActivityIndicatorView *)activityIndicator {
    objc_setAssociatedObject(self, &TAG_ACTIVITY_INDICATOR, activityIndicator, OBJC_ASSOCIATION_RETAIN);
}
#endif

- (void)sd_setShowActivityIndicatorView:(BOOL)show {
    objc_setAssociatedObject(self, &TAG_ACTIVITY_SHOW, @(show), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)sd_showActivityIndicatorView {
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_SHOW) boolValue];
}

#if SD_UIKIT
- (void)sd_setIndicatorStyle:(UIActivityIndicatorViewStyle)style{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_STYLE, [NSNumber numberWithInt:style], OBJC_ASSOCIATION_RETAIN);
}

- (int)sd_getIndicatorStyle{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_STYLE) intValue];
}
#endif

- (void)sd_addActivityIndicator {
#if SD_UIKIT
    if (!self.activityIndicator) {
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[self sd_getIndicatorStyle]];
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        
        dispatch_main_async_safe(^{
            [self addSubview:self.activityIndicator];
            
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.0]];
        });
    }
    
    dispatch_main_async_safe(^{
        [self.activityIndicator startAnimating];
    });
#endif
}

- (void)sd_removeActivityIndicator {
#if SD_UIKIT
    if (self.activityIndicator) {
        [self.activityIndicator removeFromSuperview];
        self.activityIndicator = nil;
    }
#endif
}

@end

#endif
