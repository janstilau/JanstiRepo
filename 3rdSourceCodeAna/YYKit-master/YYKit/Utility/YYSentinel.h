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
  主要起一个检验的作用, 如果闭包里面的值和当前值不一样了, 就代表已经更新了.
 */
@interface YYSentinel : NSObject

/// Returns the current value of the counter.
@property (readonly) int32_t value;

/// Increase the value atomically.
/// @return The new value.
- (int32_t)increase;

@end

NS_ASSUME_NONNULL_END
