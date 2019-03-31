//
//  MCJWT.m
//  MCMoego
//
//  Created by Zhou Kang on 2018/4/11.
//  Copyright © 2018年 Moca Inc. All rights reserved.
//

#import "MCJWT.h"

@implementation MCJWT

+ (NSDictionary *)decodeWithToken:(NSString *)token
                              key:(NSString *)key
                     shouldVerify:(BOOL)verify
                            error:(NSError **)error {
    NSArray *segments = [token componentsSeparatedByString:@"."];
    if([segments count] != 3) {
        [MCJWT setErrorWithCode:-1000 reason:@"Not enough or too many segments" error:error];
        return nil;
    }
    // Check key
    if(key == nil || [key length] == 0) {
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    // All segments should be base64
    NSString *headerSeg = segments[0];
    NSString *payloadSeg = segments[1];
    NSString *signatureSeg = segments[2];
    
    // Decode and parse header and payload JSON
    NSDictionary *header = [NSJSONSerialization JSONObjectWithData:[MCJWT base64DecodeWithString:headerSeg] options:NSJSONReadingMutableLeaves error:error];
    if(header == nil) {
        [MCJWT setErrorWithCode:-1001 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot deserialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:[MCJWT base64DecodeWithString:payloadSeg] options:NSJSONReadingMutableLeaves error:error];
    if(payload == nil) {
        [MCJWT setErrorWithCode:-1001 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot deserialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    if(verify) {
        AlgorithmType algorithmType = [MCAlgorithm getNameWithAlgorithmValue:header[@"alg"]];
        
        // Verify signature. `sign` will return base64 string
        NSString *signinInput = [[NSArray arrayWithObjects: headerSeg, payloadSeg, nil] componentsJoinedByString:@"."];
        if (![MCJWT verifyWithInput:signinInput key:key andAlgorithm:algorithmType signature:signatureSeg]) {
            [MCJWT setErrorWithCode:-1003 reason:@"Decoding failure: Signature verification failed" error:error];
            return nil;
        }
    }
    
    return payload;
}

+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                          error:(NSError **)error {
    // Check key
    if(key == nil || [key length] == 0) {
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    NSDictionary *header = @{ @"typ": @"JWT",
                              @"alg": @"HS256" };
    
    NSData *jsonHeader = [NSJSONSerialization dataWithJSONObject:header options:0 error:error];
    if(jsonHeader == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
    if(jsonPayload == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    NSMutableArray *segments = [[NSMutableArray alloc] initWithCapacity:3];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonHeader]];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonPayload]];
    [segments addObject:[MCJWT signWithInput:[segments componentsJoinedByString:@"."] key:key algorithm:HS256]];
    
    return [segments componentsJoinedByString:@"."];
}

+(NSString *) encodeWithPayload:(NSObject *)payload
                            key:(NSString *)key
                      algorithm:(AlgorithmType)algorithm
                       error:(NSError **)error {
    // Check key
    if(key == nil || [key length] == 0) {
        [MCJWT setErrorWithCode:-1004 reason:@"Key cannot be nil or empty" error:error];
        return nil;
    }
    
    NSDictionary *header = @{
                             @"typ": @"JWT",
                             @"alg": [MCAlgorithm getValueWithAlgorithmType:algorithm]
                             };
    
    NSData *jsonHeader = [NSJSONSerialization dataWithJSONObject:header options:0 error:error];
    if(jsonHeader == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize header:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    NSData *jsonPayload = [NSJSONSerialization dataWithJSONObject:payload options:0 error:error];
    if(jsonPayload == nil) {
        [MCJWT setErrorWithCode:-1002 reason:[NSString stringWithFormat:@"%@ %@", @"Cannot serialize payload:", [*error localizedFailureReason]] error:error];
        return nil;
    }
    
    NSMutableArray *segments = [[NSMutableArray alloc] initWithCapacity:3];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonHeader]];
    [segments addObject:[MCJWT base64EncodeWithBytes:jsonPayload]];
    [segments addObject:[MCJWT signWithInput:[segments componentsJoinedByString:@"."] key:key algorithm:algorithm]];
    
    return [segments componentsJoinedByString:@"."];
}

+ (NSString *)base64EncodeWithBytes:(NSData *)bytes {
    NSString *base64str = [bytes base64EncodedStringWithOptions:0];
    
    return [[[base64str stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
             stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
            stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

+ (NSData *)base64DecodeWithString:(NSString *)string {
    string = [[string stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
              stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    int size = [string length] % 4;
    NSMutableString *segment = [[NSMutableString alloc] initWithString:string];
    for (int i = 0; i < size; i++) {
        [segment appendString:@"="];
    }
    
    return [[NSData alloc] initWithBase64EncodedString:segment options:0];
}

+ (NSString *)signWithInput:(NSString *)input
                        key:(NSString *)key
                  algorithm:(AlgorithmType)algorithm {
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cInput = [input cStringUsingEncoding:NSASCIIStringEncoding];
    NSData *bytes;
    
    unsigned char cHMAC[[MCAlgorithm getDigestLengthWithAlgorithmType:algorithm]];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cInput, strlen(cInput), cHMAC);
    bytes = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    return [MCJWT base64EncodeWithBytes:bytes];
}

+ (BOOL)verifyWithInput:(NSString *)input
                 key:(NSString *)key
           andAlgorithm:(AlgorithmType)algorithm
           signature:(NSString *)signature {
    return [signature isEqualToString:[MCJWT signWithInput:input key:key algorithm:algorithm]];
}

+ (void)setErrorWithCode:(int)code
                  reason:(NSString *)reason
                   error:(NSError **)error {
    NSString *domain = @"com.himoca";
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
    *error = [[NSError alloc] initWithDomain:domain code:code userInfo:userInfo];
}

@end
