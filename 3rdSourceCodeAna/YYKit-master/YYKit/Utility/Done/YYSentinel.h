//
//  YYSentinel.h
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/4/13.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 YYSentinel is a thread safe incrementing counter. 
 It may be used in some multi-threaded situation.
 YYSentinel 哨兵. 现在仅仅用在了 AsyncLayer 里面了
 它的用法是, 闭包里面捕获它的当前值和它本身, 然后在闭包执行的时候, 检测当初捕获的值, 和它现在的值是否相等. 如果不相等, 那就是状态失效了, 闭包里面的代码就不该执行了.
 */
@interface YYSentinel : NSObject

/// Returns the current value of the counter.
@property (readonly) int32_t value;

/// Increase the value atomically.
/// @return The new value.
- (int32_t)increase;

@end

NS_ASSUME_NONNULL_END
