//
//  YYAsyncLayer.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/4/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYAsyncLayer.h"
#import "YYSentinel.h"

#if __has_include("YYDispatchQueuePool.h")
#import "YYDispatchQueuePool.h"
#else
#import <libkern/OSAtomic.h>
#endif

/// Global display queue, used for content rendering.
static dispatch_queue_t YYAsyncLayerGetDisplayQueue() {
#ifdef YYDispatchQueuePool_h
    return YYDispatchQueueGetForQOS(NSQualityOfServiceUserInitiated);
#else
#define MAX_QUEUE_COUNT 16
    static int queueCount;
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static int32_t counter = 0;
    dispatch_once(&onceToken, ^{
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            for (NSUInteger i = 0; i < queueCount; i++) {
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
                queues[i] = dispatch_queue_create("com.ibireme.yykit.render", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                queues[i] = dispatch_queue_create("com.ibireme.yykit.render", DISPATCH_QUEUE_SERIAL);
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            }
        }
    });
    int32_t cur = OSAtomicIncrement32(&counter);
    if (cur < 0) cur = -cur;
    return queues[(cur) % queueCount];
#undef MAX_QUEUE_COUNT
#endif
}

static dispatch_queue_t YYAsyncLayerGetReleaseQueue() {
#ifdef YYDispatchQueuePool_h
    return YYDispatchQueueGetForQOS(NSQualityOfServiceDefault);
#else
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
#endif
}


@implementation YYAsyncLayerDisplayTask
@end


@implementation YYAsyncLayer {
    YYSentinel *_sentinel;
}

#pragma mark - Override

+ (id)defaultValueForKey:(NSString *)key {
    if ([key isEqualToString:@"displaysAsynchronously"]) {
        return @(YES);
    } else {
        return [super defaultValueForKey:key];
    }
}

- (instancetype)init {
    self = [super init];
    static CGFloat scale; //global
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scale = [UIScreen mainScreen].scale;
        /*
         scale 表示的是, 从 point 点坐标, 到物理设备坐标的转换关系.
         This value reflects the scale factor needed to convert from the default logical coordinate space into the device coordinate space of this screen. The default logical coordinate space is measured using points. For Retina displays, the scale factor may be 3.0 or 2.0 and one point can represented by nine or four pixels, respectively. For standard-resolution displays, the scale factor is 1.0 and one point equals one pixel.
         */
    });
    /*
     This value defines the mapping between the logical coordinate space of the layer (measured in points) and the physical coordinate space (measured in pixels). Higher scale factors indicate that each point in the layer is represented by more than one pixel at render time. For example, if the scale factor is 2.0 and the layer’s bounds are 50 x 50 points, the size of the bitmap used to present the layer’s content is 100 x 100 pixels.
     The default value of this property is 1.0. For layers attached to a view, the view changes the scale factor automatically to a value that is appropriate for the current screen. For layers you create and manage yourself, you must set the value of this property yourself based on the resolution of the screen and the content you are providing. Core Animation uses the value you specify as a cue to determine how to render your content.
     系统 UIView 的 layer 会自动修改 contentScale 这个值, 自己的要手动修改.
     */
    self.contentsScale = scale;
    _sentinel = [YYSentinel new]; // 安全哨兵
    _displaysAsynchronously = YES; // 异步绘制.
    return self;
}

- (void)dealloc {
    [_sentinel increase];
}
/*
 Marks the layer’s contents as needing to be updated.
 Calling this method causes the layer to recache its content. This results in the layer potentially calling either the displayLayer: or drawLayer:inContext: method of its delegate. The existing content in the layer’s contents property is removed to make way for the new content.
 */
- (void)setNeedsDisplay {
    [self _cancelAsyncDisplay]; // 这里, cancel 就是将哨兵的计数器加一, 然后异步渲染完成之后, 如果发现计数器和自己的不一样了, 就不进行 contents 的赋值操作. 也就是说, 生成 contents 的过程不去取消, 仅仅是最后不进行赋值. 这个操作其实很常见, 例如图片的异步下载, 下载操作是不会取消的, 取消的仅仅是最后的 image = downloadImage 的赋值语句.
    [super setNeedsDisplay];
}

/*
 Do not call this method directly.
 The layer calls this method at appropriate times to update the layer’s content.
 If the layer has a delegate object, this method attempts to call the delegate’s displayLayer: method, which the delegate can use to update the layer’s contents.
 If the delegate does not implement the displayLayer: method, this method creates a backing store and calls the layer’s drawInContext: method to fill that backing store with content.
 layer’s drawInContext 不会执行任何事情, 之后调用自己delegate 的  drawLayer:inContext:, 当然了, 这个函数就会跑到 drawRect 方法里面, 把 context 的值传过去.
 所以, 改变一个视图的 layer 可以在 displayLayer, 在这里面, 直接替换 contents 的值就可以. 不然的话, 就是在 drawRect 里面, 这个时候, 就是在上下文中进行画图.
 The new backing store replaces the previous contents of the layer.
 
 Subclasses can override this method and use it to set the layer’s contents property directly. You might do this if your custom layer subclass handles layer updates differently.
 这里, 就是重写了 display 方法, 自己掌握了 contents 的赋值.
 */

- (void)display {
    super.contents = super.contents; // Assigning a value to this property causes the layer to use your image rather than create a separate backing store.
    [self _displayAsync:_displaysAsynchronously];
}

#pragma mark - Private

// 异步绘制最主要的方法.
- (void)_displayAsync:(BOOL)async {
    // 在进入到这里的时候, 这个方法还是会在主线程.
    
    __strong id<YYAsyncLayerDelegate> delegate = (id)self.delegate;
    YYAsyncLayerDisplayTask *task = [delegate newAsyncDisplayTask];
    /*
     这个 task 有三个值, 一个是 willDisplay, 代表绘制之前应该调用, 一个是 display 表示绘制的主过程, 一个是 didDisplay 表示绘制之后应该完成的人物.
     */
    if (!task.display) { // 如果, 没有主任务, 那么调用之前, 清空 contents, 之后, 然后退出.
        if (task.willDisplay) task.willDisplay(self);
        self.contents = nil;
        if (task.didDisplay) task.didDisplay(self, YES);
        return;
    }
    
    if (async) { // 如果是异步
        if (task.willDisplay) task.willDisplay(self); // 执行 willDisplay 任务.
        YYSentinel *sentinel = _sentinel;
        int32_t value = sentinel.value;
        // isCancelled 就是拿当前值和之后value 进行比较, 这里为什么要专门进行一次赋值擦欧洲.
        BOOL (^isCancelled)(void) = ^BOOL(void) {
            return value != sentinel.value;
        };
        
        CGSize size = self.bounds.size;
        BOOL opaque = self.opaque;
        CGFloat scale = self.contentsScale;
        CGColorRef backgroundColor = (opaque && self.backgroundColor) ? CGColorRetain(self.backgroundColor) : NULL;
        if (size.width < 1 || size.height < 1) {
            // 如果尺寸不对, 直接在主线程清空. 然后退出.
            CGImageRef image = (__bridge_retained CGImageRef)(self.contents);
            self.contents = nil;
            if (image) {
                dispatch_async(YYAsyncLayerGetReleaseQueue(), ^{
                    CFRelease(image); // A CFType object to release. This value must not be NULL.
                });
            }
            if (task.didDisplay) task.didDisplay(self, YES);
            CGColorRelease(backgroundColor);
            return;
        }
        
        dispatch_async(YYAsyncLayerGetDisplayQueue(), ^{
            // 在开启任务之前, 判断是不是取消了, 这个 operation 一样, 要多次判断 cancel 的值.
            if (isCancelled()) {
                CGColorRelease(backgroundColor);
                return;
            }
            
            UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (opaque && context) {
                CGContextSaveGState(context); {
                    if (!backgroundColor || CGColorGetAlpha(backgroundColor) < 1) {
                        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                    if (backgroundColor) {
                        CGContextSetFillColorWithColor(context, backgroundColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                } CGContextRestoreGState(context);
                // 这种写法很好, 让出栈入栈操作在一个逻辑单元.
                // 上面的操作, 是设置背景色.
                CGColorRelease(backgroundColor);
            }
            // 执行真正的绘制人物.
            task.display(context, size, isCancelled);
            if (isCancelled()) {
                // 如果, 绘制之后发现取消了, 那么执行失败回调.
                UIGraphicsEndImageContext();
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            // 从刚刚的绘制上下文中取得图片.
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (isCancelled()) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isCancelled()) {
                    if (task.didDisplay) task.didDisplay(self, NO);
                } else {
                    // 将图片放到 contents 里面.
                    self.contents = (__bridge id)(image.CGImage);
                    if (task.didDisplay) task.didDisplay(self, YES);
                }
            });
        });
        // 从上面我们可以看到, 在任何一个线程切换的过程中, 和耗费性能的操作之后, 都进行了 isCancelled 的判断.
        return;
    }
    // 如果是同步, 也就是在主线程完成.
    // 同步也就是没有那些 isCancelled 的判断操作了.其他的都一样.
    [_sentinel increase];
    if (task.willDisplay) task.willDisplay(self);
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, self.contentsScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.opaque && context) {
        CGSize size = self.bounds.size;
        size.width *= self.contentsScale;
        size.height *= self.contentsScale;
        CGContextSaveGState(context); {
            if (!self.backgroundColor || CGColorGetAlpha(self.backgroundColor) < 1) {
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                CGContextFillPath(context);
            }
            if (self.backgroundColor) {
                CGContextSetFillColorWithColor(context, self.backgroundColor);
                CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                CGContextFillPath(context);
            }
        } CGContextRestoreGState(context);
    }
    task.display(context, self.bounds.size, ^{return NO;});
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.contents = (__bridge id)(image.CGImage);
    if (task.didDisplay) task.didDisplay(self, YES);
}

- (void)_cancelAsyncDisplay {
    [_sentinel increase];
}

@end
