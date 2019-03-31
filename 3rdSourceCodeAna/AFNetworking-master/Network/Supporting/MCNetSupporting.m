//
//  NSString+UG_NET.m
//  MCMoego
//
//  Created by Zhou Kang on 2017/10/11.
//  Copyright © 2017年 Moca Inc. All rights reserved.
//

#import "MCNetSupporting.h"

@implementation NSString (UG_NET)

- (NSString *)ug_encode {
    NSString *outputStr = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, (CFStringRef)@"!$&'()*+,-./:;=?@_~%#[]", NULL, kCFStringEncodingUTF8));
    outputStr = [outputStr stringByReplacingOccurrencesOfString:@"<null>" withString:@""];
    return outputStr;
}

- (NSString *)ug_decode {
    NSString *outputStr = (NSString *) CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding( kCFAllocatorDefault, (__bridge CFStringRef)self, CFSTR(""), kCFStringEncodingUTF8));
    return outputStr;
}

- (id)ug_object {
    id object = nil;
    @try {
        NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
        object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"%s [Line %d] JSON字符串转换成对象出错了-->\n%@",__PRETTY_FUNCTION__, __LINE__,exception);
    }
    @finally { }
    return object;
}

- (NSString *)ug_regularJSONStr {
    // 将没有双引号的替换成有双引号的
    NSString *validString = [self stringByReplacingOccurrencesOfString:@"(\\w+)\\s*:([^A-Za-z0-9_])"
                                                            withString:@"\"$1\":$2"
                                                               options:NSRegularExpressionSearch
                                                                 range:NSMakeRange(0, [self length])];
    validString = [validString stringByReplacingOccurrencesOfString:@"([:\\[,\\{])'"
                                                         withString:@"$1\""
                                                            options:NSRegularExpressionSearch
                                                              range:NSMakeRange(0, [validString length])];
    validString = [validString stringByReplacingOccurrencesOfString:@"'([:\\],\\}])"
                                                         withString:@"\"$1"
                                                            options:NSRegularExpressionSearch
                                                              range:NSMakeRange(0, [validString length])];
    
    validString = [validString stringByReplacingOccurrencesOfString:@"([:\\[,\\{])(\\w+)\\s*:"
                                                         withString:@"$1\"$2\":"
                                                            options:NSRegularExpressionSearch
                                                              range:NSMakeRange(0, [validString length])];
    validString = [validString stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    return validString;
}

@end

// ------

@implementation NSObject (UG_NET)

- (NSString *)ug_json {
    NSString *jsonStr = @"";
    @try {
        if ([NSJSONSerialization isValidJSONObject:self]) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:kNilOptions error:nil];
            jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
        else {
            NSLog(@"data was not a proper JSON object, check All objects are NSString, NSNumber, NSArray, NSDictionary, or NSNull !!!!!");
        }
    }
    @catch (NSException *exception) {
        NSLog(@"%s [Line %d] 对象转换成JSON字符串出错了-->\n%@",__PRETTY_FUNCTION__, __LINE__,exception);
    }
    return jsonStr;
}

//去掉 json 中的多余的 null
- (id)ug_cleanNull {
    NSError *error;
    if (self == (id)[NSNull null]) {
        return [[NSObject alloc] init];
    }
    
    id jsonObject;
    if ([self isKindOfClass:[NSData class]]) {
        jsonObject = [NSJSONSerialization JSONObjectWithData:(NSData *)self options:kNilOptions error:&error];
    }
    else {
        jsonObject = self;
    }
    
    if ([jsonObject isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [jsonObject mutableCopy];
        for (NSInteger i = array.count - 1; i >= 0; i--) {
            id a = array[i];
            if (a == (id)[NSNull null]) {
                [array removeObjectAtIndex:i];
            }
            else {
                array[i] = [a ug_cleanNull];
            }
        }
        return array;
    }
    else if ([jsonObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dictionary = [jsonObject mutableCopy];
        for (NSString *key in[dictionary allKeys]) {
            id d = dictionary[key];
            if (d == (id)[NSNull null]) {
                dictionary[key] = @"";
            }
            else {
                dictionary[key] = [d ug_cleanNull];
            }
        }
        return dictionary;
    }
    else {
        return jsonObject;
    }
}

@end

// ------

@implementation NSURL (UG_NET)

- (NSString *)ug_interface {
    if (self.port) {
        return [NSString stringWithFormat:@"%@://%@: %@%@", self.scheme, self.host, self.port, self.path];
    }
    return [NSString stringWithFormat:@"%@://%@%@", self.scheme, self.host, self.path];
}

@end

// ------

@implementation NSDate (UG_NET)

- (NSString *)ug_timestamp {
    return [NSString stringWithFormat:@"%.0f", [self timeIntervalSince1970] * 1000.f];
}

+ (NSDate *)ug_dateWithTimestamp:(double)timestamp {
    if (timestamp > 140000000000) {
        timestamp = timestamp / 1000;
    }
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

@end

// ------

@implementation NSDictionary (UG_NET)

- (NSString *)mc_sortedQueryStr {
    NSArray *keys = [self allKeys];
    keys = [keys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    
    NSMutableArray *values = [NSMutableArray array];
    for (NSString *sortedKey in keys) {
        [values addObject:self[sortedKey]];
    }
    
    NSMutableArray *signArray = [NSMutableArray array];
    for (int i = 0 ; i < keys.count; i++) {
        NSString *keyValue = [NSString stringWithFormat:@"%@=%@",keys[i],values[i]];
        [signArray addObject:keyValue];
    }
    
    NSString *signString = [signArray componentsJoinedByString:@"&"];
    return signString;
}

- (NSString *)mc_sortedEncodedQueryStr {
    NSString *encodedString = [[self mc_sortedQueryStr] ug_encode];
    return encodedString;
}

@end

// ------

@implementation MCNetSupporting

+ (NSString *)generateAESKey {
    return [self generateAESKey:16];
}

+ (NSString *)generateAESKey:(NSInteger)len {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
    
    for (NSInteger i = 0; i < len; i++) {
        unichar aChar = [letters characterAtIndex: arc4random_uniform((uint32_t)[letters length])];
        [randomString appendFormat: @"%C", aChar];
    }
    return randomString.copy;
}

@end

#pragma mark - 解决中文打印问题
#if DEBUG
@implementation NSSet(Log)

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString *desc = [NSMutableString string];
    
    NSMutableString *tabString = [[NSMutableString alloc] initWithCapacity:level];
    for (NSUInteger i = 0; i < level; ++i) {
        [tabString appendString:@"\t"];
    }
    
    NSString *tab = @"\t";
    if (level > 0) {
        tab = tabString;
    }
    [desc appendString:@"\t{(\n"];
    
    for (id obj in self) {
        if ([obj isKindOfClass:[NSDictionary class]]
            || [obj isKindOfClass:[NSArray class]]
            || [obj isKindOfClass:[NSSet class]]) {
            NSString *str = [((NSDictionary *)obj) descriptionWithLocale:locale indent:level + 1];
            [desc appendFormat:@"%@\t%@,\n", tab, str];
        } else if ([obj isKindOfClass:[NSString class]]) {
            [desc appendFormat:@"%@\t\"%@\",\n", tab, obj];
        } else if ([obj isKindOfClass:[NSData class]]) {
            // if is NSData，try parse
            NSError *error = nil;
            NSObject *result =  [NSJSONSerialization JSONObjectWithData:obj
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&error];
            
            if (error == nil && result != nil) {
                if ([result isKindOfClass:[NSDictionary class]]
                    || [result isKindOfClass:[NSArray class]]
                    || [result isKindOfClass:[NSSet class]]) {
                    NSString *str = [((NSDictionary *)result) descriptionWithLocale:locale indent:level + 1];
                    [desc appendFormat:@"%@\t%@,\n", tab, str];
                } else if ([obj isKindOfClass:[NSString class]]) {
                    [desc appendFormat:@"%@\t\"%@\",\n", tab, result];
                }
            } else {
                @try {
                    NSString *str = [[NSString alloc] initWithData:obj encoding:NSUTF8StringEncoding];
                    if (str != nil) {
                        [desc appendFormat:@"%@\t\"%@\",\n", tab, str];
                    } else {
                        [desc appendFormat:@"%@\t%@,\n", tab, obj];
                    }
                }
                @catch (NSException *exception) {
                    [desc appendFormat:@"%@\t%@,\n", tab, obj];
                }
            }
        } else {
            [desc appendFormat:@"%@\t%@,\n", tab, obj];
        }
    }
    
    [desc appendFormat:@"%@)}", tab];
    
    return desc;
}

@end

@implementation NSArray (Log)

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString *desc = [NSMutableString string];
    
    NSMutableString *tabString = [[NSMutableString alloc] initWithCapacity:level];
    for (NSUInteger i = 0; i < level; ++i) {
        [tabString appendString:@"\t"];
    }
    
    NSString *tab = @"";
    if (level > 0) {
        tab = tabString;
    }
    [desc appendString:@"\t(\n"];
    
    for (id obj in self) {
        if ([obj isKindOfClass:[NSDictionary class]]
            || [obj isKindOfClass:[NSArray class]]
            || [obj isKindOfClass:[NSSet class]]) {
            NSString *str = [((NSDictionary *)obj) descriptionWithLocale:locale indent:level + 1];
            [desc appendFormat:@"%@\t%@,\n", tab, str];
        } else if ([obj isKindOfClass:[NSString class]]) {
            [desc appendFormat:@"%@\t\"%@\",\n", tab, obj];
        } else if ([obj isKindOfClass:[NSData class]]) {
            
            NSError *error = nil;
            NSObject *result =  [NSJSONSerialization JSONObjectWithData:obj
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&error];
            
            if (error == nil && result != nil) {
                if ([result isKindOfClass:[NSDictionary class]]
                    || [result isKindOfClass:[NSArray class]]
                    || [result isKindOfClass:[NSSet class]]) {
                    NSString *str = [((NSDictionary *)result) descriptionWithLocale:locale indent:level + 1];
                    [desc appendFormat:@"%@\t%@,\n", tab, str];
                } else if ([obj isKindOfClass:[NSString class]]) {
                    [desc appendFormat:@"%@\t\"%@\",\n", tab, result];
                }
            } else {
                @try {
                    NSString *str = [[NSString alloc] initWithData:obj encoding:NSUTF8StringEncoding];
                    if (str != nil) {
                        [desc appendFormat:@"%@\t\"%@\",\n", tab, str];
                    } else {
                        [desc appendFormat:@"%@\t%@,\n", tab, obj];
                    }
                }
                @catch (NSException *exception) {
                    [desc appendFormat:@"%@\t%@,\n", tab, obj];
                }
            }
        } else {
            [desc appendFormat:@"%@\t%@,\n", tab, obj];
        }
    }
    
    [desc appendFormat:@"%@)", tab];
    
    return desc;
}

@end

@implementation NSDictionary (Log)

- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level {
    NSMutableString *desc = [NSMutableString string];
    
    NSMutableString *tabString = [[NSMutableString alloc] initWithCapacity:level];
    for (NSUInteger i = 0; i < level; ++i) {
        [tabString appendString:@"\t"];
    }
    
    NSString *tab = @"";
    if (level > 0) {
        tab = tabString;
    }
    
    [desc appendString:@"\t{\n"];
    
    // Through array, self is array
    for (id key in self.allKeys) {
        id obj = [self objectForKey:key];
        
        if ([obj isKindOfClass:[NSString class]]) {
            [desc appendFormat:@"%@\t%@ = \"%@\",\n", tab, key, obj];
        } else if ([obj isKindOfClass:[NSArray class]]
                   || [obj isKindOfClass:[NSDictionary class]]
                   || [obj isKindOfClass:[NSSet class]]) {
            [desc appendFormat:@"%@\t%@ = %@,\n", tab, key, [obj descriptionWithLocale:locale indent:level + 1]];
        } else if ([obj isKindOfClass:[NSData class]]) {
            
            NSError *error = nil;
            NSObject *result =  [NSJSONSerialization JSONObjectWithData:obj
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&error];
            
            if (error == nil && result != nil) {
                if ([result isKindOfClass:[NSDictionary class]]
                    || [result isKindOfClass:[NSArray class]]
                    || [result isKindOfClass:[NSSet class]]) {
                    NSString *str = [((NSDictionary *)result) descriptionWithLocale:locale indent:level + 1];
                    [desc appendFormat:@"%@\t%@ = %@,\n", tab, key, str];
                } else if ([obj isKindOfClass:[NSString class]]) {
                    [desc appendFormat:@"%@\t%@ = \"%@\",\n", tab, key, result];
                }
            } else {
                @try {
                    NSString *str = [[NSString alloc] initWithData:obj encoding:NSUTF8StringEncoding];
                    if (str != nil) {
                        [desc appendFormat:@"%@\t%@ = \"%@\",\n", tab, key, str];
                    } else {
                        [desc appendFormat:@"%@\t%@ = %@,\n", tab, key, obj];
                    }
                }
                @catch (NSException *exception) {
                    [desc appendFormat:@"%@\t%@ = %@,\n", tab, key, obj];
                }
            }
        } else {
            [desc appendFormat:@"%@\t%@ = %@,\n", tab, key, obj];
        }
    }
    
    [desc appendFormat:@"%@}", tab];
    
    return desc;
}

@end
#endif
