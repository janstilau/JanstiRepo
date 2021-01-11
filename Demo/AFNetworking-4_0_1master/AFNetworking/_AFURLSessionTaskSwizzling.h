//
//  _AFURLSessionTaskSwizzling.h
//  AFNetworking iOS
//
//  Created by JustinLau on 2020/5/23.
//  Copyright © 2020 AFNetworking. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


extern NSString * const AFNSURLSessionTaskDidResumeNotification;
extern NSString * const AFNSURLSessionTaskDidSuspendNotification;

@interface _AFURLSessionTaskSwizzling : NSObject

@end

NS_ASSUME_NONNULL_END
