//
//  NSThread+YYAdd.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/7/3.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSThread+YYAdd.h"
#import <CoreFoundation/CoreFoundation.h>

@interface NSThread_YYAdd : NSObject @end
@implementation NSThread_YYAdd @end

#if __has_feature(objc_arc)
#error This file must be compiled without ARC. Specify the -fno-objc-arc flag to this file.
#endif

static NSString *const YYNSThreadAutoleasePoolKey = @"YYNSThreadAutoleasePoolKey";
static NSString *const YYNSThreadAutoleasePoolStackKey = @"YYNSThreadAutoleasePoolStackKey";

static const void *PoolStackRetainCallBack(CFAllocatorRef allocator, const void *value) {
    return value;
}

static void PoolStackReleaseCallBack(CFAllocatorRef allocator, const void *value) {
    CFRelease((CFTypeRef)value);
}

// 入栈, 只会在线程的 runloop 的监听者中, 进行 poolStack 的操作. 在运行过程中的自动释放池, 不会进入到 poolStack.
static inline void YYAutoreleasePoolPush() {
    NSMutableDictionary *dic =  [NSThread currentThread].threadDictionary;
    NSMutableArray *poolStack = dic[YYNSThreadAutoleasePoolStackKey];
    
    if (!poolStack) {
        /*
         do not retain pool on push,
         but release on pop to avoid memory analyze warning
         */
        CFArrayCallBacks callbacks = {0};
        callbacks.retain = PoolStackRetainCallBack;
        callbacks.release = PoolStackReleaseCallBack;
        poolStack = (id)CFArrayCreateMutable(CFAllocatorGetDefault(), 0, &callbacks);
        dic[YYNSThreadAutoleasePoolStackKey] = poolStack;
        CFRelease(poolStack);
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // create
    [poolStack addObject:pool]; // push
}

// 出栈.
static inline void YYAutoreleasePoolPop() {
    NSMutableDictionary *dic =  [NSThread currentThread].threadDictionary;
    NSMutableArray *poolStack = dic[YYNSThreadAutoleasePoolStackKey];
    [poolStack removeLastObject]; // pop
}

static void YYRunLoopAutoreleasePoolObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    switch (activity) {
        case kCFRunLoopEntry: {
            YYAutoreleasePoolPush();
        } break;
        case kCFRunLoopBeforeWaiting: {
            YYAutoreleasePoolPop();
            YYAutoreleasePoolPush();
        } break;
        case kCFRunLoopExit: {
            YYAutoreleasePoolPop();
        } break;
        default: break;
    }
}
// 监听 runloop 的状态切换.
static void YYRunloopAutoreleasePoolSetup() {
    CFRunLoopRef runloop = CFRunLoopGetCurrent();

    CFRunLoopObserverRef pushObserver;
    pushObserver = CFRunLoopObserverCreate(CFAllocatorGetDefault(), kCFRunLoopEntry,
                                           true,         // repeat
                                           -0x7FFFFFFF,  // before other observers
                                           YYRunLoopAutoreleasePoolObserverCallBack, NULL);
    CFRunLoopAddObserver(runloop, pushObserver, kCFRunLoopCommonModes);
    CFRelease(pushObserver);
    
    CFRunLoopObserverRef popObserver;
    popObserver = CFRunLoopObserverCreate(CFAllocatorGetDefault(), kCFRunLoopBeforeWaiting | kCFRunLoopExit,
                                          true,        // repeat
                                          0x7FFFFFFF,  // after other observers
                                          YYRunLoopAutoreleasePoolObserverCallBack, NULL);
    CFRunLoopAddObserver(runloop, popObserver, kCFRunLoopCommonModes);
    CFRelease(popObserver);
}

@implementation NSThread (YYAdd)

// 主线程的 runloop 会自动开启, 但是子线程的应该是没有开启.

+ (void)addAutoreleasePoolToCurrentRunloop {
    if ([NSThread isMainThread]) return; // The main thread already has autorelease pool.
    NSThread *thread = [self currentThread];
    if (!thread) return;
    if (thread.threadDictionary[YYNSThreadAutoleasePoolKey]) return; // already added
    YYRunloopAutoreleasePoolSetup(); // threadDictionary 这个东西, 就是碰过专门开放给开发者放东西用的.
    thread.threadDictionary[YYNSThreadAutoleasePoolKey] = YYNSThreadAutoleasePoolKey; // mark the state
}

@end
