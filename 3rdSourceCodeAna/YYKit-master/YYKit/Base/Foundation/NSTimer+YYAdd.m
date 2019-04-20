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

// 这里是52个方法里面的技巧. 主要就是为了 NSTimer 类对象不怕循环引用.
// 这个方法, 是所有的 timer 都会进行触发的, 具体执行什么样的回调, 根据 timeInfo 里面的信息, 这里, timeInfo 直接就是 block, 作者连封装到内部的意愿都没有.
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
