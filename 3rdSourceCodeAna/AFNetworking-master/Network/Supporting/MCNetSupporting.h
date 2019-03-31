//
//  NSString+UG_NET.h
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (UG_NET)

- (NSString *)ug_encode;
- (NSString *)ug_decode;
- (id)ug_object;
/**
 * 规范化 JSON 字符串
 */
- (NSString *)ug_regularJSONStr;

@end

// ------

@interface NSObject (UG_NET)

- (NSString *)ug_json;

@end

// ------

@interface NSURL (UG_NET)

- (NSString *)ug_interface;

@end

// ------

@interface NSDate (UG_NET)

- (NSString *)ug_timestamp;
+ (NSDate *)ug_dateWithTimestamp:(double)timestamp;

@end

// ------

@interface NSDictionary (UG_NET)

/**
 * 按照字母顺序排序，并用 & 拼接
 */
- (NSString *)mc_sortedQueryStr;
- (NSString *)mc_sortedEncodedQueryStr;

@end

// ------

@interface MCNetSupporting : NSObject

/**
 * 随机AESKey，默认16个字节
 */
+ (NSString *)generateAESKey;

@end

