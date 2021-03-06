//
//  NSNotificationCenter+YYAdd.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 13/8/24.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "NSNotificationCenter+YYAdd.h"
#include <pthread.h>
#import "YYKitMacro.h"

YYSYNTH_DUMMY_CLASS(NSNotificationCenter_YYAdd)

// 并没有特别的东西, 仅仅是对于方法的一个封装而已. 对于传值, 还是使用的 NSDictionary, 对于有着特定范围的传值来说, 用 NSDictionary 是无可厚非的.
// 但是如果使用范围比较广, NSDictionary 这种 keyValue 对应的策略, 是会让使用者感到不舒服的.
@implementation NSNotificationCenter (YYAdd)

- (void)postNotificationOnMainThread:(NSNotification *)notification {
    // 这里不用类方法不好, 不直观.
    if (pthread_main_np()) return [self postNotification:notification];
    [self postNotificationOnMainThread:notification waitUntilDone:NO];
}

- (void)postNotificationOnMainThread:(NSNotification *)notification waitUntilDone:(BOOL)wait {
    if (pthread_main_np()) return [self postNotification:notification];
    // 这里, 把操作转移到类方法上面, 还是用的系统的方法.
    [[self class] performSelectorOnMainThread:@selector(_yy_postNotification:) withObject:notification waitUntilDone:wait];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object {
    if (pthread_main_np()) return [self postNotificationName:name object:object userInfo:nil];
    [self postNotificationOnMainThreadWithName:name object:object userInfo:nil waitUntilDone:NO];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
    if (pthread_main_np()) return [self postNotificationName:name object:object userInfo:userInfo];
    [self postNotificationOnMainThreadWithName:name object:object userInfo:userInfo waitUntilDone:NO];
}

- (void)postNotificationOnMainThreadWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo waitUntilDone:(BOOL)wait {
    if (pthread_main_np()) return [self postNotificationName:name object:object userInfo:userInfo];
    NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:3];
    if (name) [info setObject:name forKey:@"name"];
    if (object) [info setObject:object forKey:@"object"];
    if (userInfo) [info setObject:userInfo forKey:@"userInfo"];
    [[self class] performSelectorOnMainThread:@selector(_yy_postNotificationName:) withObject:info waitUntilDone:wait];
}

+ (void)_yy_postNotification:(NSNotification *)notification {
    [[self defaultCenter] postNotification:notification];
}

+ (void)_yy_postNotificationName:(NSDictionary *)info {
    NSString *name = [info objectForKey:@"name"];
    id object = [info objectForKey:@"object"];
    NSDictionary *userInfo = [info objectForKey:@"userInfo"];
    
    [[self defaultCenter] postNotificationName:name object:object userInfo:userInfo];
}

@end
