//
//  NSTimer+YYAdd.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 14/15/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSTimer+YYAdd.h"
#import "YYKitMacro.h"

YYSYNTH_DUMMY_CLASS(NSTimer_YYAdd)


@implementation NSTimer (YYAdd)

// Timer 添加到 Runloop 的时候, 本身一定是被强引用的, runloop 是一个滞后的操作机制, 一定要保证在执行对应的切口的回调的时候, 回调的容器是有效的. 所以, timer 其实不太需要在类中被强引用.
// 这里, 作者的思路是, timer 的 target 引用 NSTimer 的类对象, 然后类对象调用一个方法. 而这个方法, 真正执行的方法, 其实是在参数中进行传递的.
+ (void)_yy_ExecBlock:(NSTimer *)timer {
    if ([timer userInfo]) {
        void (^block)(NSTimer *timer) = (void (^)(NSTimer *timer))[timer userInfo];
        block(timer);
    }
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds block:(void (^)(NSTimer *timer))block repeats:(BOOL)repeats {
    return [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(_yy_ExecBlock:) userInfo:[block copy] repeats:repeats];
}

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)seconds block:(void (^)(NSTimer *timer))block repeats:(BOOL)repeats {
    return [NSTimer timerWithTimeInterval:seconds target:self selector:@selector(_yy_ExecBlock:) userInfo:[block copy] repeats:repeats];
}

@end
