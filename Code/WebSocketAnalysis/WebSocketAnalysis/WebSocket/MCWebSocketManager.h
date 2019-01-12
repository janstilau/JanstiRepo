//
//  MCWebSocketManager.h
//  MCFriends
//
//  Created by JustinLau on 2019/1/10.
//  Copyright © 2019年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCWebSocketManager : NSObject

+ (instancetype)defaultManager;

- (void)openWithPayload:(NSDictionary *)payload;
- (void)close;

@end

NS_ASSUME_NONNULL_END
