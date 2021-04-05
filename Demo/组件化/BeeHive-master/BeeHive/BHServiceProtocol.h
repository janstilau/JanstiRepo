/**
 * Created by BeeHive.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the GNU GENERAL PUBLIC LICENSE.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>
#import "BHAnnotation.h"

@protocol BHServiceProtocol <NSObject>

@optional

// 是不是支持单例模式, 如果是, 就使用 shareInstance 获取到对应的单例, 作为 Imp 对象进行使用.
+ (BOOL)singleton;
+ (id)shareInstance;

@end
